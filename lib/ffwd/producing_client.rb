require_relative 'lifecycle'
require_relative 'reporter'
require_relative 'logging'

module FFWD
  # A client implementation that delegates all work to other threads.
  class ProducingClient
    include FFWD::Reporter
    include FFWD::Logging

    class Producer
      def setup
        raise "not implemented: setup"
      end

      def teardown
        raise "not implemented: teardown"
      end

      def produce events, metrics
        raise "not implemented: produce"
      end
    end

    set_reporter_keys :failed_events, :failed_metrics,
                      :dropped_events, :dropped_metrics,
                      :sent_events, :sent_metrics

    def initialize channel, producer, flush_period, event_limit, metric_limit
      @flush_period = flush_period
      @event_limit = event_limit
      @metric_limit = metric_limit

      if @flush_period <= 0
        raise "Invalid flush period: #{flush_period}"
      end

      @producer = producer
      @events = []
      @metrics = []

      # Pending request.
      @request = nil
      @timer = nil

      @subs = []

      channel.starting do
        @timer = EM::PeriodicTimer.new(@flush_period){flush!}

        @subs << channel.event_subscribe do |e|
          if @events.size >= @event_limit
            increment :dropped_events, 1
            return
          end

          @events << e
        end

        @subs << channel.metric_subscribe do |m|
          if @metrics.size >= @metric_limit
            increment :dropped_metrics, 1
            return
          end

          @metrics << m
        end

        @producer.setup
      end

      channel.stopping do
        if @timer
          @timer.cancel
          @timer = nil
        end

        flush!

        @subs.each(&:unsubscribe).clear

        @metrics.clear
        @events.clear

        @producer.teardown
      end
    end

    def reporter_id
      @producer.reporter_id
    end

    def flush!
      if @request or not @request = @producer.produce(@events, @metrics)
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
      log.error "Failed to produce", e
    ensure
      @events.clear
      @metrics.clear
    end
  end

  DEFAULT_FLUSH_PERIOD = 10
  DEFAULT_EVENT_LIMIT = 10000
  DEFAULT_METRIC_LIMIT = 10000
  DEFAULT_FLUSH_SIZE = 1000

  def self.producing_client channel, producer, opts
    flush_period = opts[:flush_period] || DEFAULT_FLUSH_PERIOD
    event_limit = opts[:event_limit] || DEFAULT_EVENT_LIMIT
    metric_limit = opts[:metric_limit] || DEFAULT_METRIC_LIMIT
    ProducingClient.new channel, producer, flush_period, event_limit, metric_limit
  end
end
