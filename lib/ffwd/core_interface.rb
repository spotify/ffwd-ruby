module FFWD
  class CoreInterface
    attr_reader :tunnels
    attr_reader :processors
    attr_reader :statistics
    attr_reader :debug
    attr_reader :tags
    attr_reader :attributes

    def initialize tunnels, processors, debug, statistics, opts
      @tunnels = tunnels
      @processors = processors
      @debug = debug
      @statistics = statistics
      @tags = opts[:tags] || []
      @attributes = opts[:attributes] || {}
    end
  end
end
