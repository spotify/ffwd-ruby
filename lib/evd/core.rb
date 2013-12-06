require 'set'
require 'json'
require 'eventmachine'

require 'evd/logging'
require 'evd/data_type'
require 'evd/protocol'
require 'evd/update_hash'
require 'evd/limited'

require 'evd/debug'
require 'evd/statistics'

module EVD
  class Core
    include EVD::Logging

    # Arbitrary default queue limit.
    # Having a queue limit is critical to make sure we never run out of memory.
    DEFAULT_BUFFER_LIMIT = 5000

    def initialize(opts={})
      @buffer_limit = opts[:buffer_limit] || DEFAULT_BUFFER_LIMIT
      @input_buffer_limit = opts[:input_buffer_limit] || @buffer_limit
      @output_buffer_limit = opts[:output_buffer_limit] || @buffer_limit
      @plugin_buffer_limit = opts[:plugin_buffer_limit] || @buffer_limit

      @input_buffer = EVD::Limited::Queue.new(
        'core input', log, @input_buffer_limit)

      @output_buffer = EVD::Limited::Queue.new(
        'core output', log, @output_buffer_limit)

      @output_buffers = []

      @metadata_limit = opts[:metadata_limit] || 10000
      @tags = Set.new(opts[:tags] || [])
      @attr = opts[:attributes] || {}

      @debug = opts[:debug]
      @debug_clients = {}

      # Configuration for a specific type.
      @types = opts[:types] || {}

      # Configuration for statistics module.
      unless (config = opts[:statistics]).nil?
        @statistics = EVD::Statistics.setup(self, config)
      else
        @statistics = nil
      end

      # Registered extensible data types.
      @datatypes = {}
      # Data types internal to core module.
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
        input_plugins.each do |type, plugin|
          plugin.start @input_buffer
        end

        output_plugins.each_with_index do |plugin_def, index|
          type, plugin = plugin_def
          output_buffer = EVD::Limited::Queue.new(
            "output ##{index} '#{type}'",
            log, @plugin_buffer_limit)
          plugin.start output_buffer
          @output_buffers << output_buffer
        end

        @datatypes.each do |name, datatype|
          next unless datatype.respond_to?(:start)
          datatype.start
        end

        @statistics.start unless @statistics.nil?

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
        event[:tags] += base_tags
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
    rescue => e
      log.error "Failed to emit event: #{e}"
      log.error e.backtrace.join("\n")
    end

    private

    def emit_debug(event)
      @debug_clients.each do |peer, client|
        data = JSON.dump(event)
        client.send_data "#{data}\n"
      end
    end

    def emit_output(event)
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
      @statistics.input_inc unless @statistics.nil?

      return if (type = msg[:type]).nil?
      return if (processor = @datatypes[type] || @internals[type]).nil?
      msg[:tags] = Set.new(msg[:tags]) unless msg[:tags].nil?
      msg[:time] = Time.now unless msg[:time]
      processor.process msg
    end

    def process_output(event)
      @statistics.output_inc unless @statistics.nil?

      @output_buffers.each do |buffer|
        buffer << event
      end
    end
  end
end
