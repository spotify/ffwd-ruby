require_relative 'lifecycle'

module FFWD
  class Tunnel
    include FFWD::Lifecycle

    class Plugin
      def subscribe protocol, port, &block
        raise "Not implemented: subscribe"
      end

      def dispatch ip, addr, data
        raise "Not implemented: dispatch"
      end
    end

    # The component that pretends to be EventMachine for the various handlers.
    class TunnelTCP
      def initialize tunnel, id, addr
        @tunnel = tunnel
        @id = id
        @addr = addr
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

      starting do
        setup
      end
    end

    def setup
      return handle_udp if @protocol == :udp
      return handle_tcp if @protocol == :tcp
      raise "Unsupported protocol: #{@protocol}"
    end

    def handle_udp
      handler_instance = @connection.new(nil, @core, *@args)
      @log.info "Tunneling to #{@protocol}://*:#{@port}"

      @tunnel.subscribe @protocol, @port do |id, addr, data|
        handler_instance.receive_data data
      end
    end

    def handle_tcp
      @tunnel.subscribe @protocol, @port do |id, addr, data|
        unless instance = @instances[addr]
          @log.debug "New connection: #{addr} (#{id}, #{@connection})"
          handler = TunnelTCP.new @tunnel, id, addr
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
