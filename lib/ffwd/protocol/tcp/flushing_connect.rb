require_relative 'connect_base'

module FFWD::TCP
  # A TCP connection implementation that buffers events and metrics in batches
  # over a time window and calls 'send_all' on the handler.
  class FlushingConnect < ConnectBase
    include FFWD::Reporter

    set_reporter_keys :dropped_events, :dropped_metrics,
                      :sent_events, :sent_metrics,
                      :failed_events, :failed_metrics,
                      :forced_flush

    def initialize(
      core, log, host, port, handler, args, outbound_limit,
      flush_period, event_limit, metric_limit, flush_limit
    )
      super log, host, port, handler, args, outbound_limit

      @flush_period = flush_period
      @event_limit = event_limit
      @event_flush_limit = flush_limit * event_limit
      @metric_limit = metric_limit
      @metric_flush_limit = flush_limit * metric_limit

      @event_buffer = []
      @metric_buffer = []
      @timer = nil

      subs = []

      core.starting do
        log.info "Flushing every #{@flush_period}s"
        @timer = EM::PeriodicTimer.new(@flush_period){flush!}

        event_consumer = setup_consumer(
          @event_buffer, @event_limit, @event_flush_limit, :dropped_events)
        metric_consumer = setup_consumer(
          @metric_buffer, @metric_limit, @metric_flush_limit, :dropped_metrics)

        subs << core.output.event_subscribe(&event_consumer)
        subs << core.output.metric_subscribe(&metric_consumer)

        connect
      end

      core.stopping do
        subs.each(&:unsubscribe).clear

        if @timer
          @timer.cancel
          @timer = nil
        end

        disconnect
      end
    end

    def flush!
      if @event_buffer.empty? and @metric_buffer.empty?
        return
      end

      unless writable?
        increment :dropped_events, @event_buffer.size
        increment :dropped_metrics, @metric_buffer.size
        return
      end

      send_all @event_buffer, @metric_buffer
      increment :sent_events, @event_buffer.size
      increment :sent_metrics, @metric_buffer.size
    rescue => e
      log.error "Failed to flush buffers", e

      log.error "The following data could not be flushed:"

      @event_buffer.each_with_index do |event, i|
        log.error "##{i}: #{event.to_h}"
      end

      @metric_buffer.each_with_index do |metric, i|
        log.error "##{i}: #{metric.to_h}"
      end

      increment :failed_events, @event_buffer.size
      increment :failed_metrics, @metric_buffer.size
    ensure
      @event_buffer.clear
      @metric_buffer.clear
    end

    private

    def setup_consumer buffer, buffer_limit, flush_limit, statistics_key
      proc do |e|
        if buffer.size >= buffer_limit
          increment statistics_key, 1
          next
        end

        buffer << e

        if buffer.size >= flush_limit
          increment :forced_flush, 1
          flush!
        end
      end
    end
  end
end
