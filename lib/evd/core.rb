require 'json'
require 'eventmachine'

require_relative 'channel'
require_relative 'core_emitter'
require_relative 'core_interface'
require_relative 'core_processor'
require_relative 'core_reporter'
require_relative 'debug'
require_relative 'logging'
require_relative 'plugin_channel'
require_relative 'processor'
require_relative 'protocol'
require_relative 'statistics'
require_relative 'utils'

module EVD
  class Core
    include EVD::Logging

    def initialize plugins, opts={}
      @tunnel_plugins = plugins[:tunnel] || []
      @input_plugins = plugins[:input] || []
      @output_plugins = plugins[:output] || []

      @statistics_opts = opts[:statistics] || {}
      @debug_opts = opts[:debug]
      @core_opts = opts[:core] || {}
      @processor_opts = opts[:processor] || {}

      @output_channel = EVD::PluginChannel.new 'output'
      @input_channel = EVD::PluginChannel.new 'input'
      @system_channel = Channel.new log, "system_channel"

      @tunnels = @tunnel_plugins.map do |plugin|
        plugin.setup self
      end

      memory_config = (@core_opts[:memory] || {})
      @memory_limit = (memory_config[:limit] || 1000).to_f.round(3)
      @memory_limit95 = @memory_limit * 0.95

      if @memory_limit < 0
        raise "memory limit must be non-negative number"
      end

      @debug = nil

      if @debug_opts
        @debug = EVD::Debug.setup @debug_opts
      end

      @processors = EVD::Processor.load @processor_opts

      @emitter = CoreEmitter.new @output_channel, @core_opts
      @processor = CoreProcessor.new @emitter, @processors

      # Configuration for statistics module.
      @statistics = nil

      if config = @statistics_opts
        @statistics = EVD::Statistics.setup @emitter, @system_channel, config
      end

      @interface = CoreInterface.new(
        @tunnels, @processors, @debug, @statistics, @core_opts)

      @input_instances = @input_plugins.map do |plugin|
        plugin.setup @interface
      end

      @output_instances = @output_plugins.map do |plugin|
        plugin.setup @interface
      end

      unless @statistics.nil?
        reporters = [@output_channel, @input_channel]
        reporters += @output_instances.select{|i| EVD.is_reporter?(i)}
        reporters += @processor.reporters

        @reporter = CoreReporter.new reporters

        @statistics.register "core", @reporter
      end
    end

    #
    # Main entry point.
    #
    # Starts an EventMachine and runs the given set of plugins.
    #
    def run
      EM.run do
        setup_memory_monitor

        @processor.start @input_channel

        @input_instances.each do |p|
          p.start @input_channel, @output_channel
        end

        @output_instances.each do |p|
          p.start @output_channel
        end

        unless @statistics.nil?
          @statistics.start
        end

        unless @debug.nil?
          @debug.start
          @debug.monitor "core.input", @input_channel, EVD::Debug::Input
          @debug.monitor "core.output", @output_channel, EVD::Debug::Output
        end
      end
    end

    private

    # Sets up a memory monitor based of :core -> :memory -> :limit.
    # Will warn at least once before shutting down.
    def setup_memory_monitor
      if @memory_limit == 0
        log.warning "WARNING!!! YOU ARE RUNNING EVD WITHOUT A MEMORY LIMIT, THIS COULD DAMAGE YOUR SYSTEM"
        log.warning "To configure it, set the (:core -> :memory -> :limit) option to a non-zero number!"
        return
      end

      log.info "Memory limited to #{@memory_limit} MB (:core -> :memory -> :limit)"

      memory_one_warning = false

      @system_channel.subscribe do |info|
        rss_mb = (info[:rss].to_f / 1000000).round(3)

        if memory_one_warning and rss_mb > @memory_limit
          log.error "Memory limit exceeded (#{rss_mb}/#{@memory_limit} MB): SHUTTING DOWN"
          EM.stop
          next
        end

        if rss_mb > @memory_limit95
          log.warning "Memory limit almost reached (#{rss_mb}/#{@memory_limit} MB)"
          memory_one_warning = true
        else
          memory_one_warning = false
        end
      end
    end
  end
end
