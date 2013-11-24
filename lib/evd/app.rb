require 'set'
require 'json'
require 'eventmachine'

require 'evd/logging'
require 'evd/data_type'
require 'evd/protocol'
require 'evd/debug'

module EVD
  class App
    include EVD::Logging

    INTERNAL_TAGS = ['evd']

    OUTPUT = "evd_output"
    OUTPUT_RATE = "#{OUTPUT}.rate"
    INPUT = "evd_input"
    INPUT_RATE = "#{INPUT}.rate"

    def initialize(opts={})
      @input_buffer = EventMachine::Queue.new
      @output_buffer = EventMachine::Queue.new
      @output_buffers = []

      @statistics_period = opts[:statistics_period] || 10
      @output_buffer_limit = opts[:output_buffer_limit] || 1000
      @metadata_limit = opts[:metadata_limit] || 10000
      @tags = opts[:tags] || []
      @attr = opts[:attributes] || {}

      @dbg = opts[:debug] || false
      @dbg_clients = {}
      @dbg_protocol = TCPProtocol
      @dbg_host = opts[:debug_host] || "localhost"
      @dbg_port = opts[:debug_port] || 9999
      @dbg_bind = "#{@dbg_host}:#{@dbg_port}"

      @input_count = 0
      @output_count = 0
      @metadata = {}

      @datatypes = {}
      @internals = {}

      @metadata_tags = {}
      @metadata_attr = {}
    end

    def run(plugins)
      @datatypes = setup_datatypes
      @internals = setup_internals

      input_plugins = plugins[:input]
      output_plugins = plugins[:output]

      EventMachine.run do
        input_plugins.each do |plugin|
          plugin.setup @input_buffer
        end

        output_plugins.each do |plugin|
          output_buffer = EventMachine::Queue.new
          plugin.setup output_buffer
          @output_buffers << output_buffer
        end

        @datatypes.each do |name, datatype|
          next unless datatype.respond_to?(:setup)
          datatype.setup
        end

        process_input_buffer
        process_output_buffer
        process_statistics

        if @dbg
          @dbg_protocol.listen(@dbg_host, @dbg_port, DebugConnection, @dbg_clients)
          log.info "DEBUG: Listening to #{@dbg_protocol.name} on #{@dbg_bind}"
        end
      end
    end

    # Is called whenever a DataType has finished processing a value.
    def emit(event)
      unless (key = event[:source_key]).nil?
        event[:tags] = @metadata_tags[key] || @tags
        event[:attributes] = @metadata_attr[key] || @attr
      else
        event[:tags] = @tags
        event[:attributes] = @attr
      end

      emit_debug event if @dbg
      emit_output event
    end

    private

    def emit_debug(event)
      @dbg_clients.each do |peer, client|
        data = JSON.dump(event)
        client.send_data "#{data}\n"
      end
    end

    def emit_output(event)
      if @output_buffer.size >= @output_buffer_limit
        log.warning "Dropping output event, limit reached"
        return
      end

      @output_buffer << event
    end

    def setup_internals
      internals = {}
      internals['tags'] = UpdateTarget.new(
        @tags, @metadata_tags, @metadata_limit,
        lambda{|a, b| Set.new(a+ b).to_a})
      internals['attr'] = UpdateTarget.new(
        @attr, @metadata_attr, @metadata_limit,
        lambda{|a, b| a.merge(b)})
      internals
    end

    def setup_datatypes
      datatypes = {}

      DataType.registry.each do |name, klass|
        log.info "DataType: #{name}"

        data_type = klass.new
        data_type.app = self
        datatypes[name] = data_type
      end

      datatypes
    end

    def process_input_buffer
      @input_buffer.pop do |msg|
        @input_count += 1
        process_input msg
        process_input_buffer
      end
    end

    def process_output_buffer
      @output_buffer.pop do |event|
        @output_count += 1
        process_output event
        process_output_buffer
      end
    end

    def process_input(msg)
      return if (type = msg[:type]).nil?
      return if (processor = @datatypes[type] || @internals[type]).nil?
      msg[:time] = Time.now unless msg[:time]
      processor.process msg
    end

    def process_output(event)
      @output_buffers.each do |buffer|
        if buffer.size >= @output_buffer_limit
          log.warning "Output buffer limit reached, dropping event for plugin"
          next
        end

        buffer << event
      end
    end

    def process_statistics
      prev = Time.now

      EventMachine::PeriodicTimer.new(@statistics_period) do
        now = Time.now

        diff = now - prev

        output_rate = @output_count / diff
        input_rate = @input_count / diff

        emit(:key => INPUT_RATE, :source_key => INPUT,
             :value => input_rate, :tags => INTERNAL_TAGS)
        emit(:key => OUTPUT_RATE, :source_key => INPUT,
             :value => output_rate, :tags => INTERNAL_TAGS)

        @output_count = 0
        @input_count = 0

        prev = now
      end
    end
  end
end
