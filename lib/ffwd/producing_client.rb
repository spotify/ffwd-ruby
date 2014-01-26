require_relative 'logging'

require_relative 'reporter'
require_relative 'plugin_base'

module FFWD
  # A client implementation that delegates all work to other threads.
  class ProducingClient < FFWD::PluginBase
    include FFWD::Logging
    include FFWD::Reporter

    set_reporter_keys :failed_events, :failed_metrics,
                      :dropped_events, :dropped_metrics,
                      :sent_events, :sent_metrics

    def initialize flush_period, flush_size, event_limit, metric_limit
      @flush_period = flush_period
      @flush_size = flush_size
      @event_limit = event_limit
      @metric_limit = metric_limit
      @events = []
      @metrics = []
      # Pending request.
      @request = nil
      @timer = nil
    end

    def init output
      @timer = EM::PeriodicTimer.new(@flush_period){flush!}

      event_sub_id = output.event_subscribe do |e|
        if @events.size >= @event_limit
          increment :dropped_events, 1
          return
        end

        @events << e
      end

      metric_sub_id = output.metric_subscribe do |m|
        if @metrics.size >= @metric_limit
          increment :dropped_metrics, 1
          return
        end

        @metrics << m
      end

      stopping do
        output.metric_unsubscribe metric_sub_id
        output.event_unsubscribe event_sub_id
      end
    end

    protected

    def produce events, metrics
      raise "Not implemented: produce"
    end

    private

    def flush!
      if @request or not @request = produce(@events, @metrics)
        increment :dropped_events, @events.size
        increment :dropped_metrics, @metrics.size
        return
      end

      @request.callback do
        increment :sent_events, @events.size
        increment :sent_metrics, @metrics.size
        @request = nil
      end

      @request.errback do
        increment :failed_events, @events.size
        increment :failed_metrics, @metrics.size
        @request = nil
      end
    rescue => e
      increment :failed_events, @events.size
      increment :failed_metrics, @metrics.size
      log.error "Failed to flush events", e
    ensure
      @events.clear
      @metrics.clear
    end
  end
end
