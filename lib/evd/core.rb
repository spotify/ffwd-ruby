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

      @statistics_opts = opts[:statistics]
      @debug_opts = opts[:debug]
      @core_opts = opts[:core] || {}
      @processor_opts = opts[:processor] || {}

      @output_channel = EVD::PluginChannel.new 'output'
      @input_channel = EVD::PluginChannel.new 'input'

      @tunnels = @tunnel_plugins.map do |plugin|
        plugin.setup self
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
        channels = [@output_channel, @input_channel]
        @statistics = EVD::Statistics.setup @emitter, channels, config
      end

      @interface = CoreInterface.new(
        @tunnels, @processors, @debug, @statistics, @core_opts)

      @input_instances = @input_plugins.map do |plugin|
        plugin.setup @interface
      end

      @output_instances = @output_plugins.map do |plugin|
        plugin.setup @interface
      end

      reporters = []
      reporters += @output_instances.select{|i| EVD.is_reporter?(i)}
      reporters += @processor.reporters

      @reporter = CoreReporter.new reporters

      @statistics.register "core", @reporter
    end

    #
    # Main entry point.
    #
    # Starts an EventMachine and runs the given set of plugins.
    #
    def run
      EM.run do
        @processor.start @input_channel

        @input_instances.each do |p|
          p.start @input_channel, @output_channel
        end

        @output_instances.each do |p|
          p.start @output_channel
        end

        @statistics.start unless @statistics.nil?

        unless @debug.nil?
          @debug.start
          @debug.monitor "core.input", @input_channel, EVD::Debug::Input
          @debug.monitor "core.output", @output_channel, EVD::Debug::Output
        end
      end
    end

    private
  end
end
