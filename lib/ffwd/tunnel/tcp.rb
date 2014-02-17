require_relative '../lifecycle'
require_relative '../reporter'

require_relative 'data_sink'

module FFWD::Tunnel
  class TCP
    include FFWD::Lifecycle
    include FFWD::Reporter

    setup_reporter :keys => [
      :received_events, :received_metrics,
      :failed_events, :failed_metrics
    ]

    attr_reader :log

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
            instance = @connection.new(nil, self, @core, *@args)
            instance.datasink = DataSink.new @plugin, id, addr
            @instances[addr] = instance
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
