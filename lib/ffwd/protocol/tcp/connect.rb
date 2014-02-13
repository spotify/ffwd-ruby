require_relative 'connect_base'

module FFWD::TCP
  class Connect < ConnectBase
    include FFWD::Reporter

    set_reporter_keys :dropped_events, :dropped_metrics,
                      :sent_events, :sent_metrics

    INITIAL_TIMEOUT = 2

    def initialize output, log, host, port, handler, args, outbound_limit
      super log, host, port, handler, args, outbound_limit

      @event_sub = nil
      @metric_sub = nil

      output.starting do
        connect
        @event_sub = output.event_subscribe{|e| handle_event e}
        @metric_sub = output.metric_subscribe{|e| handle_metric e}
      end

      output.stopping do
        disconnect

        if @event_sub
          output.event_unsubscribe @event_sub
          @event_sub = nil
        end

        if @metric_sub
          output.metric_unsubscribe @metric_sub
          @metric_sub = nil
        end
      end
    end

    def handle_event event
      return increment :dropped_events, 1 unless writable?
      send_event event
      increment :sent_events, 1
    rescue => e
      log.error "Failed to handle event", e
      log.error "The following event could not be flushed: #{event.to_h}"
      increment :failed_events, 1
    end

    def handle_metric metric
      return increment :dropped_metrics, 1 unless writable?
      send_metric metric
      increment :sent_metrics, 1
    rescue => e
      log.error "Failed to handle metric", e
      log.error "The following metric could not be flushed: #{metric.to_h}"
      increment :failed_metrics, 1
    end
  end
end
