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
  # over a time interval and calls 'send_all' on the connection.
  class FlushingConnect
    include FFWD::Reporter

    setup_reporter :keys => [
      :dropped_events, :dropped_metrics,
      :sent_events, :sent_metrics,
      :failed_events, :failed_metrics,
      :forced_flush
    ]

    attr_reader :log

    # reporter metadata is inherited from the provided connection.
    def reporter_meta
      @c.reporter_meta
    end

    def initialize(
      core, log, connection,
      flush_period, event_limit, metric_limit, flush_limit
    )
      @log = log
      @c = connection

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

        @c.connect
      end

      core.stopping do
        subs.each(&:unsubscribe).clear

        if @timer
          @timer.cancel
          @timer = nil
        end

        @c.disconnect
      end
    end

    # Call try_flush! if we have data in buffers.
    # If exception is caught, call fail_flush which will report diagnostics and
    # statistics.
    def flush!
      if @event_buffer.empty? and @metric_buffer.empty?
        return
      end

      try_flush! Time.now
    rescue => e
      fail_flush! e
    end

    private

    def try_flush! now
      unless @c.writable?
        increment :dropped_events, @event_buffer.size
        increment :dropped_metrics, @metric_buffer.size
        return
      end

      @c.send_all @event_buffer, @metric_buffer
      increment :sent_events, @event_buffer.size
      increment :sent_metrics, @metric_buffer.size
    ensure
      @event_buffer.clear
      @metric_buffer.clear
    end

    def fail_flush! e
      log.error "Failed to flush buffers", e
      log.error "The following data could NOT be sent:"

      @event_buffer.each_with_index do |event, i|
        log.error "##{i}: #{event.to_h}"
      end

      @metric_buffer.each_with_index do |metric, i|
        log.error "##{i}: #{metric.to_h}"
      end

      increment :failed_events, @event_buffer.size
      increment :failed_metrics, @metric_buffer.size
    end

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
