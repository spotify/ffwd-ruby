module EVD
  class Tunnel
    def initialize log, protocol, port, handler, args
      @log = log
      @protocol = protocol
      @port = port
      @handler = handler
      @args = args
      @peer = "?:#{port}"
    end

    def start input, output, tunnel_connection
      handler_instance = @handler.new(nil, input, output, *@args)

      @log.info "Tunneling to #{@protocol}://#{@peer}"

      tunnel_connection.subscribe @protocol, @port do |data|
        handler_instance.receive_data data
      end
    end
  end
end
