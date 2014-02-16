require_relative '../lifecycle'

module FFWD::Tunnel
  class UDP
    include FFWD::Lifecycle

    def initialize port, core, plugin, log, connection, args
      @port = port
      @core = core
      @plugin = plugin
      @log = log
      @connection = connection
      @args = args

      @instance = nil

      starting do
        @instance = @connection.new(nil, @core, *@args)

        @plugin.subscribe :udp, @port do |id, addr, data|
          @instance.receive_data data
        end

        @log.info "Tunneling udp/#{@port}"
      end

      stopping do
        if @instance
          @instance.unbind
          @instance = nil
        end

        @log.info "Stopped tunnelling udp/#{@port}"
      end
    end
  end
end
