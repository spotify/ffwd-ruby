module EVD
  class Tunnel
    # The component that pretends to be EventMachine for the various handlers.
    class TunnelTCP
      def initialize log, protocol, port, peer, tunnel
        @log = log
        @protocol = protocol
        @port = port
        @peer = peer
        @tunnel = tunnel
      end

      def << data
        @tunnel.dispatch @protocol, @port, @peer, data
      end
    end

    def initialize log, protocol, port, connection, args
      @log = log
      @protocol = protocol
      @port = port
      @connection = connection
      @args = args
      @peer = "?:#{port}"
      @instances = {}
    end

    def start input, output, tunnel
      if @protocol == 'udp'
        return handle_udp input, output, tunnel
      else
        return handle_tcp input, output, tunnel
      end
    end

    def handle_udp input, output, tunnel
      handler_instance = @connection.new(nil, input, output, *@args)
      @log.info "Tunneling to #{@protocol}://#{@peer}"

      tunnel.subscribe @protocol, @port do |peer, data|
        handler_instance.receive_data data
      end
    end

    def handle_tcp input, output, tunnel
      tunnel.subscribe @protocol, @port do |peer, data|
        unless instance = @instances[peer]
          @log.info "New connection: #{peer} (#{@connection})"
          handler = TunnelTCP.new @log, @protocol, @port, peer, tunnel
          instance = @instances[peer] = @connection.new(nil, input, output, *@args)
          instance.datasink = handler
        end

        if data == ""
          @log.info "Close connection: #{peer}"
          instance.unbind
          @instances.delete peer
        end

        instance.receive_data data
      end
    end
  end
end
