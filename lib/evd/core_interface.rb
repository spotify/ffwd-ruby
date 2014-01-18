module EVD
  class CoreInterface
    attr_reader :tunnels
    attr_reader :processors
    attr_reader :tags
    attr_reader :attributes
    attr_reader :debug

    def initialize tunnels, processors, debug, opts
      @tunnels = tunnels
      @processors = processors
      @debug = debug
      @tags = opts[:tags] || []
      @attributes = opts[:attributes] || {}
    end
  end
end
