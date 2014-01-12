require_relative 'logging'
require_relative 'reporter'

module EVD
  # A client implementation that delegates all work to other threads.
  class ProducingClient
    include EVD::Logging
    include EVD::Reporter

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

    def start channel
      @timer = EM::PeriodicTimer.new(@flush_period){flush!}

      channel.event_subscribe do |e|
        return increment :dropped_events, 1 if @events.size >= @event_limit
        @events << e
      end

      channel.metric_subscribe do |m|
        return increment :dropped_metrics, 1 if @metrics.size >= @metric_limit
        @metrics << m
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
