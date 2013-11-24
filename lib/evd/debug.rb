require 'eventmachine'

require 'evd/logging'

module EVD
  module Debug
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

    class TCP
      include EVD::Logging

      def initialize(clients, host, port)
        @clients = clients
        @host = host
        @port = port
        @peer = "#{@host}:#{@port}"
      end

      def start
        EventMachine.start_server(
          @host, @port, DebugConnection, @clients)
        log.info "Listening on #{@peer}"
      end
    end

    def self.setup(clients, opts={})
      host = opts[:host] || "localhost"
      port = opts[:port] || 9999
      proto = EVD.parse_protocol(opts[:protocol] || "tcp")

      return TCP.new clients, host, port if proto == :tcp

      throw Exception.new("Unsupported protocol '#{proto}'")
    end
  end
end
