require_relative '../lifecycle'

module FFWD::Debug
  class MonitorSession
    attr_reader :id

    def initialize id, channel, type
      @type = type
      @clients = {}

      subs = []

      channel.starting do
        subs << channel.event_subscribe do |event|
          data = @type.serialize_event event

          begin
            send JSON.dump(:id => @id, :type => :event, :data => data)
          rescue => e
            log.error "Failed to serialize event", e
            return
          end
        end

        subs << channel.metric_subscribe do |metric|
          data = @type.serialize_metric metric

          begin
            send JSON.dump(:id => @id, :type => :metric, :data => data)
          rescue => e
            log.error "Failed to serialize metric", e
            return
          end
        end
      end

      channel.stopping do
        subs.each(&:unsubscribe).clear
      end
    end

    def register peer, client
      @clients[peer] = client
    end

    def unregister peer, client
      @clients.delete peer
    end

    def send line
      @clients.each do |peer, client|
        client.send_line line
      end
    end
  end
end
