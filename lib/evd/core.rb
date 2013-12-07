require 'set'
require 'json'
require 'eventmachine'

require 'evd/logging'
require 'evd/data_type'
require 'evd/protocol'
require 'evd/update_hash'
require 'evd/channel'

require 'evd/debug'
require 'evd/statistics'

module EVD
  class Core
    include EVD::Logging

    # Arbitrary default queue limit.
    # Having a queue limit is critical to make sure we never run out of memory.
    DEFAULT_BUFFER_LIMIT = 5000
    DEFAULT_REPORT_INTERVAL = 600

    def initialize(opts={})
      @buffer_limit = opts[:buffer_limit] || DEFAULT_BUFFER_LIMIT
      @input_buffer_limit = opts[:input_buffer_limit] || @buffer_limit
      @output_buffer_limit = opts[:output_buffer_limit] || @buffer_limit
      @plugin_buffer_limit = opts[:plugin_buffer_limit] || @buffer_limit
      @report_interval = opts[:report_interval] || DEFAULT_REPORT_INTERVAL

      @input_channel = EVD::Channel.new(log, 'input')
      @output_channel = EVD::Channel.new(log, 'output')

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
      @reporters = []
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

      @reporters = []
      @reporters += setup_reporters(@datatypes.values)
      @reporters += setup_reporters(output_plugins)

      log.info "Registered #{@reporters.size} reporter(s)"

      EM.run do
        input_plugins.each {|p| p.start @input_channel}
        output_plugins.each {|p| p.start @output_channel}

        @datatypes.each do |name, datatype|
          next unless datatype.respond_to?(:start)
          datatype.start
        end

        @statistics.start unless @statistics.nil?

        unless @debug.nil?
          debug = EVD::Debug.setup @debug_clients, @debug
          debug.start
        end

        unless @reporters.empty?
          EM::PeriodicTimer.new(@report_interval) do
            process_reporters
          end
        end

        @input_channel.subscribe do |event|
          process_input event
        end
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

      @statistics.output_inc unless @statistics.nil?

      @output_channel << event
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

        datatype = klass.new(@types[name] || {})
        datatype.core = self
        datatypes[name] = datatype
      end

      datatypes
    end

    def setup_reporters(instances)
      reporters = []

      instances.each do |i|
        next unless i.respond_to? :report and i.respond_to? :report?
        reporters << i
      end

      reporters
    end

    def process_reporters
      active = []

      @reporters.each do |reporter|
        active << reporter if reporter.report?
      end

      return if active.empty?

      active.each do |reporter|
        reporter.report
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
  end
end
