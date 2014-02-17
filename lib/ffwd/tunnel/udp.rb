require_relative '../lifecycle'
require_relative '../reporter'

module FFWD::Tunnel
  class UDP
    include FFWD::Lifecycle
    include FFWD::Reporter

    setup_reporter :keys => [
      :received_events, :received_metrics, :failed_events, :failed_metrics]

    attr_reader :log

    def initialize port, core, plugin, log, connection, args
      @port = port
      @core = core
      @plugin = plugin
      @log = log
      @connection = connection
      @args = args

      @instance = nil

      starting do
        @instance = @connection.new(nil, self, @core, *@args)

        @plugin.udp @port do |handle, data|
          @instance.datasink = handle
          @instance.receive_data data
          @instance.datasink = nil
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
