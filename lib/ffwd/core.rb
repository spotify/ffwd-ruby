require 'json'
require 'eventmachine'

require_relative 'channel'
require_relative 'core_emitter'
require_relative 'core_interface'
require_relative 'core_processor'
require_relative 'core_reporter'
require_relative 'debug'
require_relative 'lifecycle'
require_relative 'logging'
require_relative 'plugin_channel'
require_relative 'processor'
require_relative 'protocol'
require_relative 'statistics'
require_relative 'utils'

module FFWD
  class Core
    include FFWD::Lifecycle
    include FFWD::Logging

    def initialize plugins, opts={}
      @tunnel_plugins = plugins[:tunnel] || []
      @input_plugins = plugins[:input] || []
      @output_plugins = plugins[:output] || []

      @statistics_opts = opts[:statistics]
      @debug_opts = opts[:debug]
      @core_opts = opts[:core] || {}
      @processors = FFWD::Processor.load_processors(opts[:processor] || {})

      @output_channel = FFWD::PluginChannel.build 'output'
      @input_channel = FFWD::PluginChannel.build 'input'

      @system_channel = Channel.new log, "system_channel"

      memory_config = (@core_opts[:memory] || {})
      @memory_limit = (memory_config[:limit] || 1000).to_f.round(3)
      @memory_limit95 = @memory_limit * 0.95

      if @memory_limit < 0
        raise "memory limit must be non-negative number"
      end

      @emitter = CoreEmitter.build @output_channel, @core_opts
      @processor = CoreProcessor.build @input_channel, @emitter, @processors

      @debug = nil

      if @debug_opts
        @debug = FFWD::Debug.setup @debug_opts
        @debug.monitor "core.input", @input_channel, FFWD::Debug::Input
        @debug.monitor "core.output", @output_channel, FFWD::Debug::Output
        @debug.depend_on self
      end

      # Configuration for statistics module.
      @statistics = nil

      if config = @statistics_opts
        @statistics = FFWD::Statistics.setup @emitter, @system_channel, config
        @statistics.depend_on self
      end

      @interface = CoreInterface.new(
        @input_channel, @output_channel,
        @tunnel_plugins, @statistics, @debug, @processors, @core_opts
      )

      @interface.depend_on self

      @input_instances = @input_plugins.map do |plugin|
        plugin.setup @interface
      end

      @output_instances = @output_plugins.map do |plugin|
        plugin.setup @interface
      end

      unless @statistics.nil?
        reporters = [@input_channel, @output_channel, @processor]
        reporters += @input_instances.select{|i| FFWD.is_reporter?(i)}
        reporters += @output_instances.select{|i| FFWD.is_reporter?(i)}
        @statistics.register "core", CoreReporter.new(reporters)
      end

      # Make the core-related channels depend on core.
      # They will then be orchestrated with core when it's being
      # started/stopped.
      @input_channel.depend_on self
      @output_channel.depend_on self
    end

    # Main entry point.
    #
    # Since all components are governed by the lifecycle of core, it should
    # mostly be a matter of calling 'start'.
    def run
      # What to do when we receive a shutdown signal?
      shutdown_handler = proc do
        # Hack to get out of trap context and into EM land.
        EM.add_timer(0) do
          log.info "Shutting down"
          stop
          EM.stop
        end
      end

      EM.run do
        Signal.trap("INT", &shutdown_handler)
        Signal.trap("TERM", &shutdown_handler)

        start
        setup_memory_monitor
      end

      stopping do
      end
    end

    private

    # Sets up a memory monitor based of :core -> :memory -> :limit.
    # Will warn at least once before shutting down.
    def setup_memory_monitor
      if @memory_limit == 0
        log.warning "WARNING!!! YOU ARE RUNNING FFWD WITHOUT A MEMORY LIMIT, THIS COULD DAMAGE YOUR SYSTEM"
        log.warning "To configure it, set the (:core -> :memory -> :limit) option to a non-zero number!"
        return
      end

      log.info "Memory limited to #{@memory_limit} MB (:core -> :memory -> :limit)"

      memory_one_warning = false

      @system_channel.subscribe do |system|
        memory = system[:memory]

        mb = (memory[:resident].to_f / 1000000).round(3)

        if memory_one_warning and mb > @memory_limit
          log.error "Memory limit exceeded (#{mb}/#{@memory_limit} MB): SHUTTING DOWN"
          EM.stop
          next
        end

        if mb > @memory_limit95
          log.warning "Memory limit almost reached (#{mb}/#{@memory_limit} MB)"
          memory_one_warning = true
        else
          memory_one_warning = false
        end
      end
    end
  end
end
