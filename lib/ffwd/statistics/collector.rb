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

require_relative '../lifecycle'

require_relative 'system_statistics'

module FFWD::Statistics
  class Collector
    include FFWD::Lifecycle

    DEFAULT_PERIOD = 10
    DEFAULT_PREFIX = "ffwd"

    # Initialize the statistics collector.
    #
    # emitter - The emitter used to dispatch metrics for all reporters and
    # statistics collectors.
    # channel - A side-channel used by the SystemStatistics component
    # to report information about the system. Messages sent on this channel
    # help Core decide if it should seppuku.
    def initialize log, emitter, channel, opts={}
      @emitter = emitter
      @period = opts[:period] || DEFAULT_PERIOD
      @tags = opts[:tags] || []
      @attributes = opts[:attributes] || {}
      @reporters = {}
      @channel = channel
      @timer = nil
      @prefix = opts[:prefix] || DEFAULT_PREFIX

      system = SystemStatistics.new(opts[:system] || {})

      if system.check
        @system = system
      else
        @system = nil
      end

      starting do
        log.info "Started statistics collection"

        @last = Time.now

        @timer = EM::PeriodicTimer.new @period do
          now = Time.now
          generate! @last, now
          @last = now
        end
      end

      stopping do
        log.info "Stopped statistics collection"

        if @timer
          @timer.cancel
          @timer = nil
        end
      end
    end

    def generate! last, now
      if @system
        @system.collect @channel do |key, value|
          key = "#{@prefix}.#{key}"
          @emitter.metric.emit(
            :key => key, :value => value,
            :tags => @tags, :attributes => @attributes)
        end
      end

      @reporters.each do |id, reporter|
        reporter.report! do |d|
          attributes = FFWD.merge_hashes @attributes, d[:meta]
          key = "#{@prefix}.#{d[:key]}"
          @emitter.metric.emit(
            :key => key, :value => d[:value],
            :tags => @tags, :attributes => attributes)
        end
      end
    end

    def register id, reporter
      @reporters[id] = reporter
    end

    def unregister id
      @reporters.delete id
    end
  end
end
