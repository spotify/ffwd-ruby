module FFWD
  class Tunnel
    # The component that pretends to be EventMachine for the various handlers.
    class TunnelTCP
      def initialize core, log, id, addr, tunnel
        @core = core
        @log = log
        @id = id
        @addr = addr
        @tunnel = tunnel
      end

      def << data
        @tunnel.dispatch @id, @addr, data
      end
    end

    def initialize core, tunnel, log, protocol, port, connection, args
      @core = core
      @tunnel = tunnel
      @log = log
      @protocol = protocol
      @port = port
      @connection = connection
      @args = args
      @peer = "?:#{port}"
      @instances = {}
    end

    def start tunnel
      return handle_udp tunnel if @protocol == :udp
      return handle_tcp tunnel if @protocol == :tcp
      raise "Unsupported protocol: #{@protocol}"
    end

    def handle_udp tunnel
      handler_instance = @connection.new(nil, @core, *@args)
      @log.info "Tunneling to #{@protocol}://#{@addr}"

      tunnel.subscribe @protocol, @port do |id, addr, data|
        handler_instance.receive_data data
      end
    end

    def handle_tcp tunnel
      tunnel.subscribe @protocol, @port do |id, addr, data|
        unless instance = @instances[addr]
          @log.debug "New connection: #{addr} (#{id}, #{@connection})"
          handler = TunnelTCP.new @log, id, addr, tunnel
          instance = @instances[addr] = @connection.new(nil, @core, *@args)
          instance.datasink = handler
        end

        if data.nil? or data.empty?
          @log.debug "Close connection: #{addr}"
          instance.unbind
          @instances.delete addr
          next
        end

        instance.receive_data data
      end
    end
  end
end
