module FFWD::Tunnel
  class DataSink
    def initialize plugin, id, addr
      @plugin = plugin
      @id = id
      @addr = addr
    end

    def << data
      @plugin.dispatch @id, @addr, data
    end
  end
end
