require_relative '../lifecycle'

module FFWD
  class Core; end

  class Core::Interface
    include FFWD::Lifecycle

    attr_reader :input, :output
    attr_reader :tunnel_plugins, :statistics, :debug, :processors
    attr_reader :tags, :attributes

    def initialize(input, output, tunnel_plugins, statistics, debug,
                   processors, opts)
      @input = input
      @output = output
      @tunnel_plugins = tunnel_plugins
      @statistics = statistics
      @debug = debug
      @processors = processors
      @opts = opts
      @tags = opts[:tags] || []
      @attributes = opts[:attributes] || {}
    end

    def reconnect input
      self.class.new(
        input, @output, @tunnel_plugins, @statistics, @debug, @processors,
        @opts)
    end
  end
end
