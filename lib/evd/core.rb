require 'set'
require 'json'
require 'eventmachine'

require 'evd/logging'
require 'evd/data_type'
require 'evd/protocol'
require 'evd/update_hash'
require 'evd/debug'

module EVD
  class Core
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

      @statistics_period = opts[:statistics_period] || 1
      @output_buffer_limit = opts[:output_buffer_limit] || 1000
      @metadata_limit = opts[:metadata_limit] || 10000
      @tags = opts[:tags] || []
      @attr = opts[:attributes] || {}

      @debug = opts[:debug]
      @debug_clients = {}

      @statistics_precision = opts[:statistics_precision] || 3
      @statistics_then = nil
      @input_count = 0
      @output_count = 0
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

        unless @debug.nil?
          debug = EVD::Debug.setup @debug_clients, @debug
          debug.start
        end
      end
    end

    #
    # Emit an event.
    #
    def emit(event)
      unless (key = event[:source_key]).nil?
        event[:tags] = @metadata_tags[key] || @tags
        event[:attributes] = @metadata_attr[key] || @attr
      else
        event[:tags] = @tags
        event[:attributes] = @attr
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
        lambda{|a, b| Set.new(a+ b).to_a})
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

        data_type = klass.new
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
      @input_count += 1

      return if (type = msg[:type]).nil?
      return if (processor = @datatypes[type] || @internals[type]).nil?
      msg[:time] = Time.now unless msg[:time]
      processor.process msg
    end

    def process_output(event)
      @output_count += 1

      @output_buffers.each do |buffer|
        if buffer.size >= @output_buffer_limit
          log.warning "Output buffer limit reached, dropping event for plugin"
          next
        end

        buffer << event
      end
    end

    def process_statistics
      @statistics_then = Time.now

      EventMachine::PeriodicTimer.new(@statistics_period) do
        generate_statistics
      end
    end

    def generate_statistics
      now = Time.now
      diff = now - @statistics_then

      input_rate = (@input_count.to_f / diff).round @statistics_precision
      output_rate = (@output_count.to_f / diff).round @statistics_precision

      @input_count = 0
      @output_count = 0

      emit(:key => INPUT_RATE, :source_key => INPUT,
           :value => input_rate, :tags => INTERNAL_TAGS)
      emit(:key => OUTPUT_RATE, :source_key => INPUT,
           :value => output_rate, :tags => INTERNAL_TAGS)

      @statistics_then = now
    end
  end
end
