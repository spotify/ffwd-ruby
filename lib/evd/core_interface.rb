module EVD
  class CoreInterface
    attr_reader :tunnels
    attr_reader :processors

    def initialize tunnels, processors
      @tunnels = tunnels
      @processors = processors
    end
  end
end
