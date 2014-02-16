require_relative '../lifecycle'

module FFWD::Tunnel
  class TCP
    include FFWD::Lifecycle

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

    def initialize port, core, plugin, log, connection, args
      @port = port
      @core = core
      @plugin = plugin
      @log = log
      @connection = connection
      @args = args
      @instances = {}

      starting do
        @plugin.subscribe :tcp, @port do |id, addr, data|
          unless instance = @instances[addr]
            @log.debug "New connection: #{addr} (#{id}, #{@connection})"
            instance = @instances[addr] = @connection.new(nil, @core, *@args)
            instance.datasink = DataSink.new @plugin, id, addr
          end

          if data.nil? or data.empty?
            @log.debug "Close connection: #{addr}"
            instance.unbind
            @instances.delete addr
            next
          end

          instance.receive_data data
        end

        @log.info "Tunneling tcp/#{@port}"
      end

      stopping do
        @instances.each do |addr, instance|
          instance.unbind
        end

        @instances.clear
        @log.info "Stopped tunneling tcp/#{@port}"
      end
    end
  end
end
