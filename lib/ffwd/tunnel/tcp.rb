require_relative '../lifecycle'
require_relative '../reporter'

module FFWD::Tunnel
  class TCP
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

      starting do
        @plugin.tcp @port do |handle|
          log.debug "Open tcp/#{@port}"

          instance = @connection.new(nil, self, @core, *@args)
          instance.datasink = handle

          handle.data do |data|
            instance.receive_data data
          end

          handle.close do
            log.debug "Close tcp/#{@port}"
            instance.unbind
          end
        end
      end

      stopping do
        log.info "Stopped tunneling tcp/#{@port}"
      end
    end
  end
end
