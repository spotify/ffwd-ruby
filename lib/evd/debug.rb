require 'eventmachine'

require 'evd/logging'

module EVD
  class DebugConnection < EventMachine::Connection
    include EVD::Logging

    def initialize(clients)
      @clients = clients
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
      @clients[@peer] = self
      log.info "#{@ip}:#{@port}: connected"
    end

    def unbind
      @clients.delete @peer
      log.info "#{@ip}:#{@port}: disconnected"
    end

    def receive_data(data); end
  end
end
