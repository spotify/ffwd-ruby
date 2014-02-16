require_relative 'connect_base'

module FFWD::TCP
  class Connect < ConnectBase
    include FFWD::Reporter

    setup_reporter :keys => [
      :dropped_events, :dropped_metrics,
      :sent_events, :sent_metrics
    ]

    INITIAL_TIMEOUT = 2

    def initialize core, log, host, port, handler, args, outbound_limit
      super log, host, port, handler, args, outbound_limit

      subs = []

      core.starting do
        connect
        subs << core.output.event_subscribe{|e| handle_event e}
        subs << core.output.metric_subscribe{|e| handle_metric e}
      end

      core.stopping do
        disconnect
        subs.each(&:unsubscribe).clear
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
