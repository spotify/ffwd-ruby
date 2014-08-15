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

require 'ffwd/reporter'

require_relative 'utils'

module FFWD::Plugin::Datadog
  class Output
    include FFWD::Reporter

    report_meta :component => :datadog, :direction => :out

    report_key :dropped_metrics, :meta => {:what => :dropped_metrics, :unit => :metric}
    report_key :failed_metrics, :meta => {:what => :failed_metrics, :unit => :metric}
    report_key :sent_metrics, :meta => {:what => :sent_metrics, :unit => :metric}

    attr_reader :log, :reporter_meta

    HEADER = {
      "Content-Type" => "application/json"
    }

    API_PATH = "/api/v1/series"

    def initialize core, log, url, datadog_key, flush_interval, buffer_limit
      @log = log
      @url = url
      @datadog_key = datadog_key
      @flush_interval = flush_interval
      @buffer_limit = buffer_limit
      @reporter_meta = {:url => @url}

      @buffer = []
      @pending = nil
      @c = nil

      @sub = nil

      core.starting do
        log.info "Started, sending metrics to #{@url}"

        @c = EM::HttpRequest.new(@url)

        @sub = core.output.metric_subscribe do |metric|
          if @buffer.size >= @buffer_limit
            increment :dropped_metrics, 1
            next
          end

          @buffer << metric
          check_timer!
        end
      end

      core.stopping do
        # Close is buggy, don.
        #@c.close

        log.info "Closing connection to #{@url}"

        if @sub
          @sub.unsubscribe
          @sub = nil
        end

        if @timer
          @timer.cancel
          @timer = nil
        end
      end
    end

    def flush!
      if @timer
        @timer.cancel
        @timer = nil
      end

      if @pending
        log.info "Request already in progress, dropping metrics"
        increment :dropped_metrics, @buffer.size
        @buffer.clear
        return
      end

      unless @c
        log.error "Dropping metrics, no active connection available"
        increment :dropped_metrics, @buffer.size
        @buffer.clear
        return
      end

      buffer_size = @buffer.size
      metrics = Utils.make_metrics(@buffer)
      metrics = JSON.dump(metrics)
      @buffer.clear

      log.info "Sending #{buffer_size} metric(s) to #{@url}"
      @pending = @c.post(:path => API_PATH,
                         :query => {'api_key' => @datadog_key },
                         :head => HEADER,
                         :body => metrics)

      @pending.callback do
        increment :sent_metrics, buffer_size
        @pending = nil
      end

      @pending.errback do
        log.error "Failed to submit metrics: #{@pending.error}"
        increment :failed_metrics, buffer_size
        @pending = nil
      end
    end

    def check_timer!
      return if @timer

      log.debug "Setting timer to #{@flush_interval}s"

      @timer = EM::Timer.new(@flush_interval) do
        flush!
      end
    end
  end
end
