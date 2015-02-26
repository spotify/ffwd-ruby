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
  class PlainConnect
    include FFWD::Reporter

    attr_reader :log

    def self.prepare opts
      opts
    end

    report_meta :protocol => :tcp, :direction => :output

    report_key :dropped_events, :meta => {:what => "dropped-events", :unit => :event}
    report_key :dropped_metrics, :meta => {:what => "dropped-metrics", :unit => :metric}

    report_key :sent_events, :meta => {:what => "sent-events", :unit => :event}
    report_key :sent_metrics, :meta => {:what => "sent-metrics", :unit => :metric}

    report_key :failed_events, :meta => {:what => "failed-events", :unit => :event}
    report_key :failed_metrics, :meta => {:what => "failed-metrics", :unit => :metric}

    def reporter_meta
      @c.reporter_meta
    end

    INITIAL_TIMEOUT = 2

    def initialize core, log, connection, config
      @log = log
      @c = connection

      ignored = config[:ignored]

      subs = []

      core.starting do
        @c.connect

        unless ignored.include? :events
          subs << core.output.event_subscribe{|e| handle_event e}
        end

        unless ignored.include? :metrics
          subs << core.output.metric_subscribe{|e| handle_metric e}
        end
      end

      core.stopping do
        @c.disconnect
        subs.each(&:unsubscribe).clear
      end
    end

    def handle_event event
      return increment :dropped_events, 1 unless @c.writable?
      @c.send_event event
      increment :sent_events, 1
    rescue => e
      log.error "Failed to handle event", e
      log.error "The following event could not be flushed: #{event.to_h}"
      increment :failed_events, 1
    end

    def handle_metric metric
      return increment :dropped_metrics, 1 unless @c.writable?
      @c.send_metric metric
      increment :sent_metrics, 1
    rescue => e
      log.error "Failed to handle metric", e
      log.error "The following metric could not be flushed: #{metric.to_h}"
      increment :failed_metrics, 1
    end
  end
end
