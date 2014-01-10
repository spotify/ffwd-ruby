require 'set'
require 'json'
require 'eventmachine'

require 'evd/logging'
require 'evd/protocol'
require 'evd/input_channel'
require 'evd/channel'

require 'evd/processor'

require 'evd/debug'
require 'evd/statistics'

module EVD
  # Merge two sets
  def self.merge_sets(a, b)
    return b if not a
    r = a.clone
    r += b if b
  end

  # Merge two hashes.
  def self.merge_hashes(a, b)
    return b if not a
    r = a.clone
    r.update(b) if b
  end

  class Core
    include EVD::Logging

    # Arbitrary default queue limit.
    # Having a queue limit is critical to make sure we never run out of memory.
    DEFAULT_BUFFER_LIMIT = 5000
    DEFAULT_REPORT_INTERVAL = 600

    def initialize(opts={})
      @report_interval = opts[:report_interval] || DEFAULT_REPORT_INTERVAL

      @metrics = EVD::Channel.new(log, 'metrics')
      @events = EVD::Channel.new(log, 'events')
      @output_channel = EVD::Channel.new(log, 'output')

      @plugin_channel = EVD::PluginChannel.new @metrics, @events

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
        input_plugins.each {|p| p.start @plugin_channel}
        output_plugins.each {|p| p.start @output_channel}

        @processors.each do |name, processor|
          next unless processor.respond_to?(:start)
          processor.start self
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

        @metrics.subscribe do |m|
          process_metrics m
        end

        @events.subscribe do |e|
          process_events e
        end
      end
    end

    #
    # Emit an event.
    #
    def emit(event, tags=nil, attributes=nil)
      event = EVD.event event
      event.tags = EVD.merge_sets @tags, tags
      event.attributes = EVD.merge_hashes @attributes, attributes
      event.time ||= Time.now
      event.host ||= @host if @host
      event.ttl ||= @ttl if @ttl

      emit_debug event unless @debug.nil?

      @statistics.output_inc unless @statistics.nil?
      @output_channel << event
    rescue => e
      log.error "Failed to emit event", e
    end

    private

    def emit_debug(event)
      @debug_clients.each do |peer, client|
        client.send_data "#{event}\n"
      end
    end

    #
    # setup hash of datatype functions.
    #
    def setup_processors
      processors = {}

      Processor.registry.each do |name, klass|
        processors[name] = klass.new(@processor_opts[name] || {})
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

      active.each_with_index do |reporter, i|
        reporter.report "report ##{i}"
      end
    end

    class EventEmitter
      def initialize(core, tags, attributes)
        @core = core
        @tags = tags
        @attributes = attributes
      end

      def emit(m, tags=nil, attributes=nil)
        tags = EVD.merge_sets @tags, tags
        attributes = EVD.merge_hashes @attributes, attributes
        @core.emit m, tags, attributes
      end
    end

    def process_metrics(m)
      @statistics.input_inc unless @statistics.nil?

      return if (processor = m[:processor]).nil?
      return if (processor = @processors[processor]).nil?

      core = if m[:tags] or m[:attributes]
        EventEmitter.new self, m[:tags], m[:attributes]
      else
        self
      end

      m[:time] ||= Time.now
      processor.process core, m
    end

    def process_events(e)
      @statistics.input_inc unless @statistics.nil?

      e[:time] ||= Time.now
      emit e
    end
  end
end
