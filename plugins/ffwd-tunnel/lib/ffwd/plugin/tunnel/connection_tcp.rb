require 'ffwd/connection'

module FFWD::Plugin::Tunnel
  class ConnectionTCP < FFWD::Connection
    include FFWD::Logging
    include EM::Protocols::LineText2

    def initialize core, tunnel_protocol
      @core = core
      @tunnel_protocol = tunnel_protocol
      @protocol_instance = nil
    end

    def receive_line line
      @protocol_instance.receive_line line
    end

    def dispatch id, addr, data
      @protocol_instance.dispatch id, addr, data
    end

    def receive_binary_data data
      @protocol_instance.receive_binary_data data
    end

    def get_peer
      peer = get_peername
      port, ip = Socket.unpack_sockaddr_in(peer)
      "#{ip}:#{port}"
    end

    def post_init
      @protocol_instance = @tunnel_protocol.new @core, self
    end

    def unbind
      log.info "Shutting down tunnel connection"
      @protocol_instance.stop
      @protocol_instance = nil
    end

    def metadata?
      not @metadata.nil?
    end
  end
end
