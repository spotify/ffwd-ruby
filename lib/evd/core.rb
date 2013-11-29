require 'set'
require 'json'
require 'eventmachine'

require 'evd/logging'
require 'evd/data_type'
require 'evd/protocol'
require 'evd/update_hash'

require 'evd/debug'
require 'evd/statistics'

module EVD
  class Core
    include EVD::Logging

    def initialize(opts={})
      @input_buffer = EventMachine::Queue.new
      @output_buffer = EventMachine::Queue.new
      @output_buffers = []

      @output_buffer_limit = opts[:output_buffer_limit] || 1000
      @metadata_limit = opts[:metadata_limit] || 10000
      @tags = Set.new(opts[:tags] || [])
      @attr = opts[:attributes] || {}

      @debug = opts[:debug]
      @debug_clients = {}

      # Configuration for a specific type.
      @types = opts[:types] || {}

      @statistics = opts[:statistics]
      @s = nil

      @metadata = {}

      @datatypes = {}
      @internals = {}

      @metadata_tags = {}
      @metadata_attr = {}
    end

    #
    # Main entry point.
    #
    # Starts an EventMachine and runs the given set of plugins.
    #
    def run(plugins)
      @datatypes = setup_datatypes
      @internals = setup_internals

      input_plugins = plugins[:input]
      output_plugins = plugins[:output]

      EventMachine.run do
        input_plugins.each do |plugin|
          plugin.start @input_buffer
        end

        output_plugins.each do |plugin|
          output_buffer = EventMachine::Queue.new
          plugin.start output_buffer
          @output_buffers << output_buffer
        end

        @datatypes.each do |name, datatype|
          next unless datatype.respond_to?(:start)
          datatype.start
        end

        unless @statistics.nil?
          @s = EVD::Statistics.setup(self, @statistics)
          @s.start
        end

        unless @debug.nil?
          debug = EVD::Debug.setup @debug_clients, @debug
          debug.start
        end

        process_input_buffer
        process_output_buffer
      end
    end

    #
    # Emit an event.
    #
    def emit(event)
      unless (key = event[:source_key]).nil?
        base_tags = @metadata_tags[key] || @tags
        base_attr = @metadata_attr[key] || @attr
      else
        base_tags = @tags
        base_attr = @attr
      end

      if event[:tags].nil?
        event[:tags] = base_tags
      else
        event[:tags] = event[:tags] + base_tags
      end

      if event[:attributes].nil?
        event[:attributes] = base_attr
      else
        event[:attributes] = base_attr.merge(event[:attributes])
      end

      unless @debug.nil?
        emit_debug event
      end

      emit_output event
    end

    private

    def emit_debug(event)
      @debug_clients.each do |peer, client|
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

    #
    # setup hash of internal functions.
    #
    def setup_internals
      internals = {}
      internals['tags'] = UpdateHash.new(
        @tags, @metadata_tags, @metadata_limit,
        lambda{|a, b| a + b})
      internals['attr'] = UpdateHash.new(
        @attr, @metadata_attr, @metadata_limit,
        lambda{|a, b| a.merge(b)})
      internals
    end

    #
    # setup hash of datatype functions.
    #
    def setup_datatypes
      datatypes = {}

      DataType.registry.each do |name, klass|
        log.info "DataType: #{name}"

        data_type = klass.new(@types[name] || {})
        data_type.core = self
        datatypes[name] = data_type
      end

      datatypes
    end

    def process_input_buffer
      @input_buffer.pop do |msg|
        process_input msg
        process_input_buffer
      end
    end

    def process_output_buffer
      @output_buffer.pop do |event|
        process_output event
        process_output_buffer
      end
    end

    def process_input(msg)
      @s.input_inc unless @s.nil?

      return if (type = msg[:type]).nil?
      return if (processor = @datatypes[type] || @internals[type]).nil?
      msg[:tags] = Set.new(msg[:tags]) unless msg[:tags].nil?
      msg[:time] = Time.now unless msg[:time]
      processor.process msg
    end

    def process_output(event)
      @s.output_inc unless @s.nil?

      @output_buffers.each do |buffer|
        if buffer.size >= @output_buffer_limit
          log.warning "Output buffer limit reached, dropping event for plugin"
          next
        end

        buffer << event
      end
    end
  end
end
