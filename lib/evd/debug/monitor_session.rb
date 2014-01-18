module EVD::Debug
  class MonitorSession
    attr_reader :id

    def initialize id, channel, type
      @id = id
      @channel = channel
      @type = type
      @clients = {}
      @event_sub = nil
      @metric_sub = nil
    end

    def register peer, client
      @clients[peer] = client
    end

    def unregister peer, client
      @clients.delete peer
    end

    def start
      @event_sub = @channel.event_subscribe do |event|
        data = @type.serialize_event event

        begin
          send JSON.dump(:id => @id, :type => :event, :data => data)
        rescue => e
          log.error "Failed to serialize event", e
          return
        end
      end

      @metric_sub = @channel.metric_subscribe do |metric|
        data = @type.serialize_metric metric

        begin
          send JSON.dump(:id => @id, :type => :metric, :data => data)
        rescue => e
          log.error "Failed to serialize metric", e
          return
        end
      end
    end

    # Stop function, in case some resources need freeing.
    def stop
      @channel.event_unsubscribe @event_sub if @event_sub
      @channel.metric_unsubscribe @metric_sub if @metric_sub
      @event_sub = nil
      @metric_sub = nil
    end

    def send line
      @clients.each do |peer, client|
        client.send_line line
      end
    end
  end
end
