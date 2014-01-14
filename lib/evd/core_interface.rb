module EVD
  class CoreInterface
    attr_reader :tunnels
    attr_reader :processors
    attr_reader :tags
    attr_reader :attributes

    def initialize tunnels, processors, opts
      @tunnels = tunnels
      @processors = processors
      @tags = Set.new(opts[:tags] || [])
      @attributes = opts[:attributes] || {}
    end
  end
end
