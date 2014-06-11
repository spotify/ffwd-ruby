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

require_relative '../../reporter'

module FFWD::TCP
  # A TCP connection implementation that buffers events and metrics in batches
  # over a time window and calls 'send_all' on the connection.
  class FlushingConnect
    include FFWD::Reporter

    # percent of maximum events/metrics which will cause a flush.
    DEFAULT_FORCED_FLUSH_FACTOR = 0.8
    # defaults for buffered connections.
    # maximum amount of events to buffer up.
    DEFAULT_EVENT_LIMIT = 1000
    # maximum amount of metrics to buffer up.
    DEFAULT_METRIC_LIMIT = 10000

    setup_reporter :keys => [
      :dropped_events, :dropped_metrics,
      :sent_events, :sent_metrics,
      :failed_events, :failed_metrics,
      :forced_flush
    ]

    attr_reader :log

    def reporter_meta
      @c.reporter_meta
    end

    def self.prepare opts
      opts[:forced_flush_factor] ||= DEFAULT_FORCED_FLUSH_FACTOR
      opts[:event_limit] ||= DEFAULT_EVENT_LIMIT
      opts[:metric_limit] ||= DEFAULT_METRIC_LIMIT
      opts
    end

    def initialize(core, log, connection, config)
      @log = log
      @c = connection

      flush_period = config[:flush_period]
      ignored = config[:ignored]
      forced_flush_factor = config[:forced_flush_factor]
      event_limit = config[:event_limit]
      metric_limit = config[:metric_limit]

      @event_buffer = []
      @metric_buffer = []
      @timer = nil
      @subs = []

      core.starting do
        @c.connect

        @timer = EM::PeriodicTimer.new(flush_period){flush!}

        unless ignored.include? :events
          event_consumer = setup_consumer(
            @event_buffer, event_limit, forced_flush_factor, :dropped_events)
          @subs << core.output.event_subscribe(&event_consumer)
        end

        unless ignored.include? :metrics
          metric_consumer = setup_consumer(
            @metric_buffer, metric_limit, forced_flush_factor, :dropped_metrics)
          @subs << core.output.metric_subscribe(&metric_consumer)
        end
      end

      core.stopping do
        @c.disconnect

        if @timer
          @timer.cancel
          @timer = nil
        end

        @subs.each(&:unsubscribe).clear
      end
    end

    def flush!
      if @event_buffer.empty? and @metric_buffer.empty?
        return
      end

      unless @c.writable?
        increment :dropped_events, @event_buffer.size
        increment :dropped_metrics, @metric_buffer.size
        return
      end

      @c.send_all @event_buffer, @metric_buffer
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

    def setup_consumer buffer, drop_limit, forced_flush_factor, statistics_key
      forced_flush_limit = drop_limit * forced_flush_factor

      proc do |e|
        if buffer.size >= drop_limit
          increment statistics_key, 1
          next
        end

        buffer << e

        if buffer.size >= forced_flush_limit
          increment :forced_flush, 1
          flush!
        end
      end
    end
  end
end
