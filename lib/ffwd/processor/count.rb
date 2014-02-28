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

require_relative '../processor'
require_relative '../logging'
require_relative '../event'
require_relative '../utils'
require_relative '../reporter'

module FFWD::Processor
  #
  # Implements counting statistics (similar to statsd).
  #
  class CountProcessor
    include FFWD::Logging
    include FFWD::Processor
    include FFWD::Reporter

    register_processor "count"
    setup_reporter(
      :reporter_meta => {:processor => "count"},
      :keys => [:dropped, :received]
    )

    def initialize emitter, opts={}
      @emitter = emitter
      @cache_limit = opts[:cache_limit] || 1000
      @timeout = opts[:timeout] || 300
      @period = opts[:period] || 10
      @cache = {}
      @timer = nil

      starting do
        log.info "Starting count processor on a window of #{@period}s"
      end

      stopping do
        log.info "Stopping count processor"
        @timer.cancel if @timer
        @timer = nil
      end
    end

    def flush_caches! now
      @cache.each do |cache_key, entry|
        key = entry[:key]
        count = entry[:count]
        last = entry[:last]

        # OK to modify the hash being iterated over.
        if now - last > @timeout
          @cache.delete cache_key
          next
        end

        attributes = entry[:attributes]
        tags = entry[:tags]

        entry[:count] = 0

        @emitter.metric.emit(
          :key => key, :value => count, :source => key,
          :attributes => attributes, :tags => tags)
      end
    end

    def check_timer
      return if @timer

      log.debug "Starting timer"

      @timer = EM::Timer.new(@period) do
        @timer = nil
        digest! Time.now
      end
    end

    def digest! now
      ms = FFWD.timing do
        flush_caches! now
      end

      log.debug "Digest took #{ms}ms"
    end

    def process m
      key = m[:key]
      value = m[:value]

      now = Time.now

      cache_key = [key, (m[:attributes] || {})].hash

      unless (entry = @cache[cache_key])
        return increment :dropped if @cache.size >= @cache_limit
        entry = @cache[cache_key] = {
          :key => key,
          :count => 0, :last => now, :tags => m[:tags],
          :attributes => m[:attributes]}
      end

      increment :received
      entry[:count] += value
      entry[:last] = now
      check_timer
    end
  end
end
