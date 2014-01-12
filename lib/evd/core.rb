require 'set'
require 'json'
require 'eventmachine'

require_relative 'channel'
require_relative 'debug'
require_relative 'event_emitter'
require_relative 'logging'
require_relative 'plugin_channel'
require_relative 'processor'
require_relative 'protocol'
require_relative 'statistics'
require_relative 'utils'

module EVD
  class Core
    include EVD::Logging

    # Arbitrary default queue limit.
    # Having a queue limit is critical to make sure we never run out of memory.
    DEFAULT_BUFFER_LIMIT = 5000
    DEFAULT_REPORT_INTERVAL = 600

    def initialize(opts={})
      @report_interval = opts[:report_interval] || DEFAULT_REPORT_INTERVAL

      @output = EVD::PluginChannel.new 'output'
      @input = EVD::PluginChannel.new 'input'

      @metadata_limit = opts[:metadata_limit] || 10000
      @tags = Set.new(opts[:tags] || [])
      @attributes = opts[:attributes] || {}

      @debug_opts = opts[:debug]
      @debug = nil

      # Configuration for a specific type.
      @processor_opts = opts[:processor_opts] || {}

      # Configuration for statistics module.
      unless (config = opts[:statistics]).nil?
        @statistics = EVD::Statistics.setup(self, [@output, @input], config)
      else
        @statistics = nil
      end

      # Registered extensible data types.
      @processors = {}
      @reporters = []

      @host = opts[:host]
      @ttl = opts[:ttl]
    end

    #
    # Main entry point.
    #
    # Starts an EventMachine and runs the given set of plugins.
    #
    def run(plugins)
      @processors = setup_processors

      input_plugins = plugins[:input]
      output_plugins = plugins[:output]

      @reporters = []
      @reporters += setup_reporters(@processors.values)
      @reporters += setup_reporters(output_plugins)

      log.info "Registered #{@reporters.size} reporter(s)"

      EM.run do
        input_plugins.each {|p| p.start @input}
        output_plugins.each {|p| p.start @output}

        @processors.each do |name, processor|
          next unless processor.respond_to?(:start)
          processor.start self
        end

        unless @statistics.nil?
          @statistics.start
        end

        unless @debug_opts.nil?
          @debug = EVD::Debug.setup @debug_opts
          @debug.start
        end

        unless @reporters.empty?
          EM::PeriodicTimer.new(@report_interval) do
            process_reporters
          end
        end

        @input.metric_subscribe{|m| process_metric m}
        @input.event_subscribe{|e| process_event e}
      end
    end

    #
    # Emit an event.
    #
    def emit_event e, tags=nil, attributes=nil
      event = EVD.event e

      event.time ||= Time.now
      event.host ||= @host if @host
      event.ttl ||= @ttl if @ttl
      event.tags = EVD.merge_sets @tags, tags
      event.attributes = EVD.merge_hashes @attributes, attributes

      unless @debug.nil?
        @debug.handle_event "emit_event", event
      end

      @output.event event
    rescue => e
      log.error "Failed to emit event", e
    end

    def emit_metric m, tags=nil, attributes=nil
      metric = EVD.metric m

      metric.time ||= Time.now
      metric.host ||= @host if @host
      metric.tags = EVD.merge_sets @tags, tags
      metric.attributes = EVD.merge_hashes @attributes, attributes

      unless @debug.nil?
        @debug.handle_metric "emit_metric", metric
      end

      @output.metric metric
    rescue => e
      log.error "Failed to emit metric", e
    end

    private

    #
    # setup hash of datatype functions.
    #
    def setup_processors
      processors = {}

      Processor.registry.each do |name, klass|
        processors[name] = klass.new(@processor_opts[name] || {})
      end

      if processors.empty?
        raise "No processors loaded"
      end

      log.info "Loaded processors: #{processors.keys.join(', ')}"
      return processors
    end

    def setup_reporters instances
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

      active.each_with_index do |reporter, i|
        reporter.report "report ##{i}"
      end
    end

    def process_metric m
      m[:time] ||= Time.now

      unless (p = m[:proc] and p = @processors[p]).nil?
        return emit_metric m
      end

      core = if m[:tags] or m[:attributes]
        EventEmitter.new self, m[:tags], m[:attributes]
      else
        self
      end

      p.process core, m
    end

    def process_event e
      e[:time] ||= Time.now
      emit_event e
    end
  end
end
