require 'set'
require 'json'
require 'eventmachine'

require_relative 'channel'
require_relative 'core_emitter'
require_relative 'core_interface'
require_relative 'core_processor'
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

    # Arbitrary default queue limit.
    # Having a queue limit is critical to make sure we never run out of memory.
    DEFAULT_BUFFER_LIMIT = 5000
    DEFAULT_REPORT_INTERVAL = 600

    def initialize plugins, opts={}
      @tunnel_plugins = plugins[:tunnel] || []
      @bind_plugins = plugins[:bind] || []
      @connect_plugins = plugins[:connect] || []

      @report_interval = opts[:report_interval] || DEFAULT_REPORT_INTERVAL

      @statistics_opts = opts[:statistics]
      @debug_opts = opts[:debug]
      @core_opts = opts[:core] || {}
      @processor_opts = opts[:processor] || {}

      @output = EVD::PluginChannel.new 'output'
      @input = EVD::PluginChannel.new 'input'

      @tunnels = @tunnel_plugins.map do |plugin|
        plugin.setup self
      end

      @debug = nil

      if @debug_opts
        @debug = EVD::Debug.setup @debug_opts
      end

      @processors = EVD::Processor.load @processor_opts
      @interface = CoreInterface.new @tunnels, @processors, @debug, @core_opts

      @emitter = CoreEmitter.new @output, @core_opts
      @processor = CoreProcessor.new @emitter, @processors

      @bind_instances = @bind_plugins.map do |plugin|
        plugin.setup @interface
      end

      @connect_instances = @connect_plugins.map do |plugin|
        plugin.setup @interface
      end

      # Configuration for statistics module.
      @statistics = nil

      if config = @statistics_opts
        @statistics = EVD::Statistics.setup @emitter, [@output, @input], config
      end

      @reporters = []
      @reporters += EVD.setup_reporters @connect_instances
      @reporters += @processor.reporters
    end

    #
    # Main entry point.
    #
    # Starts an EventMachine and runs the given set of plugins.
    #
    def run
      log.info "Registered #{@reporters.size} reporter(s)"

      EM.run do
        @processor.start @input

        @bind_instances.each do |p|
          p.start @input, @output
        end

        @connect_instances.each do |p|
          p.start @output
        end

        @statistics.start unless @statistics.nil?

        unless @debug.nil?
          @debug.start
          @debug.monitor "core.input", @input, EVD::Debug::Input
          @debug.monitor "core.output", @output, EVD::Debug::Output
        end

        unless @reporters.empty?
          EM::PeriodicTimer.new @report_interval do
            report!
          end
        end
      end
    end

    private

    def report!
      active = []

      @reporters.each do |reporter|
        active << reporter if reporter.report?
      end

      return if active.empty?

      active.each_with_index do |reporter, i|
        reporter.report "report ##{i}"
      end
    end
  end
end
