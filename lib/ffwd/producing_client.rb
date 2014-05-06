# $LICENSE
# Copyright 2013-2014 Spotify AB. All rights reserved.
#
# The contents of this file are licensed under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with the
# License. You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

require_relative 'lifecycle'
require_relative 'reporter'
require_relative 'logging'

module FFWD
  # A client implementation that delegates all work to other threads.
  class ProducingClient
    include FFWD::Reporter
    include FFWD::Logging

    class Producer
      def setup; raise "not implemented: setup"; end
      def teardown; raise "not implemented: teardown"; end
      def produce events, metrics; raise "not implemented: produce"; end
    end

    setup_reporter :keys => [
      # number of events/metrics that we attempted to dispatch but failed.
      :failed_events, :failed_metrics,
      # number of events/metrics that were dropped because the output buffers
      # are full.
      :dropped_events, :dropped_metrics,
      # number of events/metrics successfully sent.
      :sent_events, :sent_metrics,
      # number of requests that take longer than the allowed period.
      :slow_requests
    ]

    def reporter_meta
      @reporter_meta ||= @producer.reporter_meta.merge(
        :type => "producing_client_out")
    end

    def report! now, interval=1
      super do |m|
        yield m
      end

      return unless @producer_is_reporter

      @producer.report! now, interval do |m|
        yield m
      end
    end

    def initialize channel, producer, flush_period, event_limit, metric_limit
      @flush_period = flush_period
      @event_limit = event_limit
      @metric_limit = metric_limit

      if @flush_period <= 0
        raise "Invalid flush period: #{flush_period}"
      end

      @producer = producer
      @producer_is_reporter = FFWD.is_reporter? producer

      @events = []
      @metrics = []

      # Pending request.
      @request = nil
      @timer = nil

      @subs = []

      channel.starting do
        @timer = EM::PeriodicTimer.new(@flush_period){safer_flush!}

        @subs << channel.event_subscribe do |e|
          if @events.size >= @event_limit
            increment :dropped_events
            next
          end

          @events << e
        end

        @subs << channel.metric_subscribe do |m|
          if @metrics.size >= @metric_limit
            increment :dropped_metrics
            next
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

    # Apply some heuristics to determine if we can 'ignore' the current flush
    # to prevent loss of data.
    #
    # Checks that if a request is pending; we have not breached the limit of
    # allowed events.
    def safer_flush!
      if @request
        increment :slow_requests

        ignore_flush = (
          @events.size < @event_limit or
          @metrics.size < @metric_limit)

        return if ignore_flush
      end

      flush!
    end

    def flush!
      if @request or not @request = @producer.produce(@events, @metrics)
        increment :dropped_events, @events.size
        increment :dropped_metrics, @metrics.size
        return
      end

      # store buffer sizes for use in callbacks.
      events_size = @events.size
      metrics_size = @metrics.size

      @request.callback do
        increment :sent_events, events_size
        increment :sent_metrics, metrics_size
        @request = nil
      end

      @request.errback do |e|
        log.error "Failed to produce", e
        increment :failed_events, events_size
        increment :failed_metrics, metrics_size
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
