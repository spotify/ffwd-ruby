module EVD::Debug
  class Connection < EM::Connection
    include EVD::Logging

    def initialize handler
      @handler = handler
      @peer = nil
      @ip = nil
      @port = nil
    end

    def get_peer
      peer = get_peername
      port, ip = Socket.unpack_sockaddr_in(peer)
      return peer, ip, port
    end

    def post_init
      @peer, @ip, @port = get_peer
      @handler.register_client @peer, self
      log.info "#{@ip}:#{@port}: Connect"
    end

    def unbind
      @handler.unregister_client @peer, self
      log.info "#{@ip}:#{@port}: Disconnect"
    end

    def send_line line
      send_data "#{line}\n"
    end
  end
end
