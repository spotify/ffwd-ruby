require_relative 'lifecycle'

module FFWD
  class CoreInterface
    include FFWD::Lifecycle

    attr_reader :input, :output
    attr_reader :tunnel_plugins, :statistics, :debug, :processor_opts
    attr_reader :tags, :attributes

    def initialize(input, output, tunnel_plugins, statistics, debug,
                   processor_opts, opts)
      @input = input
      @output = output
      @tunnel_plugins = tunnel_plugins
      @statistics = statistics
      @debug = debug
      @processor_opts = processor_opts
      @opts = opts
      @tags = opts[:tags] || []
      @attributes = opts[:attributes] || {}
    end

    def reconnect input
      self.class.new(
        input, @output, @tunnel_plugins, @statistics, @debug, @processor_opts,
        @opts)
    end
  end
end
