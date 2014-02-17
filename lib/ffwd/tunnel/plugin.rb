# describes the protocol that has to be implemented by a tunnel.

module FFWD::Tunnel
  class Plugin
    def subscribe protocol, port, &block
      raise "Not implemented: subscribe"
    end

    def dispatch ip, addr, data
      raise "Not implemented: dispatch"
    end
  end
end
