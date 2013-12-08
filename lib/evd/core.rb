require 'set'
require 'json'
require 'eventmachine'

require 'evd/logging'
require 'evd/protocol'
require 'evd/update_hash'
require 'evd/channel'

require 'evd/processor'

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
      @report_interval = opts[:report_interval] || DEFAULT_REPORT_INTERVAL

      @input_channel = EVD::Channel.new(log, 'input')
      @output_channel = EVD::Channel.new(log, 'output')

      @metadata_limit = opts[:metadata_limit] || 10000
      @tags = Set.new(opts[:tags] || [])
      @attributes = opts[:attributes] || {}

      @debug = opts[:debug]
      @debug_clients = {}

      # Configuration for a specific type.
      @processor_opts = opts[:processor_opts] || {}

      # Configuration for statistics module.
      unless (config = opts[:statistics]).nil?
        @statistics = EVD::Statistics.setup(self, config)
      else
        @statistics = nil
      end

      # Registered extensible data types.
      @processors = {}
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
      @processors = setup_processors
      @internals = setup_internals

      input_plugins = plugins[:input]
      output_plugins = plugins[:output]

      @reporters = []
      @reporters += setup_reporters(@processors.values)
      @reporters += setup_reporters(output_plugins)

      log.info "Registered #{@reporters.size} reporter(s)"

      EM.run do
        input_plugins.each {|p| p.start @input_channel}
        output_plugins.each {|p| p.start @output_channel}

        @processors.each do |name, processor|
          next unless processor.respond_to?(:start)
          processor.start
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
      event = EVD.event event

      event.tags = @metadata_tags[event.source] || @tags
      event.attributes = @metadata_attr[event.source] || @attributes
      event.time ||= Time.new.to_i

      unless @debug.nil?
        emit_debug event
      end

      @statistics.output_inc unless @statistics.nil?

      @output_channel << event
    rescue => e
      log.error "Failed to emit event", e
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
    def setup_processors
      processors = {}

      Processor.registry.each do |name, klass|
        processor = klass.new(@processor_opts[name] || {})
        processor.core = self
        processors[name] = processor
      end

      raise "No processors loaded" if processors.empty?
      log.info "Loaded processors: #{processors.keys.join(', ')}"
      return processors
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
      return if (processor = @processors[type] || @internals[type]).nil?

      msg[:tags] = Set.new(msg[:tags]) unless msg[:tags].nil?
      msg[:time] = Time.now unless msg[:time]
      processor.process msg
    end
  end
end
