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

module FFWD
  class FlushingOutput
    include FFWD::Reporter

    report_meta :direction => :output

    report_key :dropped_metrics, :meta => {:what => "dropped-metrics", :unit => :metric}
    report_key :failed_metrics, :meta => {:what => "failed-metrics", :unit => :metric}
    report_key :sent_metrics, :meta => {:what => "sent-metrics", :unit => :metric}

    attr_reader :log, :reporter_meta

    def initialize core, log, hook, config
      @log = log
      @flush_interval = config[:flush_interval]
      @buffer_limit = config[:buffer_limit]
      @hook = hook
      @reporter_meta = @hook.reporter_meta

      @buffer = []
      @pending = nil
      @c = nil

      @sub = nil

      core.starting do
        @log.info "Started"
        @log.info "  config: #{config}"

        @hook.connect

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
        @log.info "Stopped"

        @hook.close

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
        @log.info "Request already in progress, dropping metrics"
        increment :dropped_metrics, @buffer.size
        @buffer.clear
        return
      end

      unless @hook.active?
        @log.error "Dropping metrics, no active connection available"
        increment :dropped_metrics, @buffer.size
        @buffer.clear
        return
      end

      buffer_size = @buffer.size

      @pending = @hook.send @buffer

      @pending.callback do
        increment :sent_metrics, buffer_size
        @pending = nil
      end

      @pending.errback do
        @log.error "Failed to submit metrics: #{@pending.error}"
        increment :failed_metrics, buffer_size
        @pending = nil
      end
    rescue => e
      @log.error "Error during flush", e
    ensure
      @buffer.clear
    end

    def check_timer!
      return if @timer

      @log.debug "Setting timer to #{@flush_interval}s"

      @timer = EM::Timer.new(@flush_interval) do
        flush!
      end
    end

    class Setup
      attr_reader :config

      def initialize log, hook, config
        @log = log
        @hook = hook
        @config = config
      end

      def connect core
        FlushingOutput.new core, @log, @hook, @config
      end
    end
  end

  def self.flushing_output log, hook, config={}
    raise "Expected: flush_interval" unless config[:flush_interval]
    raise "Expected: buffer_limit" unless config[:buffer_limit]
    FlushingOutput::Setup.new log, hook, config
  end
end
