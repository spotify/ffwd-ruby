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
require_relative '../logging'

require_relative 'system_statistics'

module FFWD::Statistics
  class Collector
    include FFWD::Lifecycle
    include FFWD::Logging

    DEFAULT_PERIOD = 10
    DEFAULT_PREFIX = "ffwd"

    def self.build emitter, channel, opts={}
      opts[:period] ||= DEFAULT_PERIOD
      opts[:prefix] ||= DEFAULT_PREFIX
      opts[:tags] ||= []
      opts[:attributes] ||= {}
      system = SystemStatistics.new(opts[:system] || {})
      system = if system.check then system end
      new emitter, channel, system, opts
    end

    # Initialize the statistics collector.
    #
    # emitter - The emitter used to dispatch metrics for all reporters and
    # statistics collectors.
    # channel - A side-channel used by the SystemStatistics component
    # to report information about the system. Messages sent on this channel
    # help Core decide if it should seppuku.
    def initialize emitter, channel, system, opts
      @emitter = emitter
      @channel = channel
      @system = system
      @period = opts[:period]
      @prefix = opts[:prefix]
      @tags = opts[:tags]
      @attributes = opts[:attributes]

      @reporters = {}
      @timer = nil

      starting do
        @last = Time.now

        @timer = EM::PeriodicTimer.new @period do
          now = Time.now
          generate! @last, now
          @last = now
        end

        log.info "Started #{opts.inspect}"
      end

      stopping do
        if @timer
          @timer.cancel
          @timer = nil
        end

        log.info "Stopped"
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

    def register lifecycle, id, reporter
      lifecycle.starting do
        @reporters[id] = reporter
      end

      lifecycle.stopping do
        @reporters.delete id
      end
    end
  end
end
