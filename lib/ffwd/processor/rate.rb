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

require 'ffwd/processor'
require 'ffwd/logging'
require 'ffwd/reporter'

module FFWD::Processor
  #
  # Implements rate statistics (similar to derive in collectd).
  #
  class RateProcessor
    include FFWD::Logging
    include FFWD::Processor
    include FFWD::Reporter

    register_processor "rate"

    report_meta :component => :processor, :processor => :rate
    report_key :dropped, {:meta => {:what => :dropped, :unit => :value}}
    report_key :expired, {:meta => {:what => :expired, :unit => :value}}
    report_key :received, {:meta => {:what => :received, :unit => :value}}

    # Options:
    #
    # :precision - The precision to round to for emitted values.
    # :cache_limit - Maxiumum amount of items allowed in the cache.
    # :min_age - Minimum age that an item has to have in the cache to calculate
    # rates.
    # This exists to prevent too frequent updates to the cache which would
    # yield very static or jumpy rates.
    # Can be set to null to disable.
    # :ttl - Allowed age of items in cache in seconds.
    # If this is nil, items will never expire, so old elements will not be
    # expunged until data type is restarted.
    def self.prepare config={}
      config[:precision] ||= 3
      config[:cache_limit] ||= 10000
      config[:min_age] ||= 0.5
      config[:ttl] ||= 600
      config
    end

    def initialize emitter, config={}
      @emitter = emitter

      @precision = config[:precision]
      @limit = config[:cache_limit]
      @min_age = config[:min_age]
      @ttl = config[:ttl]

      # keep a reference to the expire cache to prevent having to allocate it
      # all the time.
      @expire = Hash.new
      # Cache of active events.
      @cache = Hash.new

      starting do
        @timer = EM.add_periodic_timer(@ttl){expire!} unless @ttl.nil?
        log.info "Started"
        log.info "  config: #{config.inspect}"
      end

      stopping do
        log.info "Stopping rate processor"
        @timer.cancel if @timer
      end
    end

    # Expire cached events that are too old.
    def expire!
      now = Time.new

      @cache.each do |key, value|
        diff = (now - value[:time])
        next if diff < @ttl
        @expire[key] = value
      end

      unless @expire.empty?
        increment :expired, @cache.size - @expire.size
        @cache = @expire
        @expire = Hash.new
      end
    end

    def process msg
      key = msg[:key]
      time = msg[:time]
      value = msg[:value] || 0

      unless (prev = @cache[key]).nil?
        prev_time = prev[:time]
        prev_value = prev[:value]

        diff = (time - prev_time)

        valid = @ttl.nil? or diff < @ttl
        aged = @min_age.nil? or diff > @min_age

        if diff > 0 and valid and aged
          rate = ((value - prev_value) / diff)
          rate = rate.round(@precision) unless @precision.nil?
          @emitter.metric.emit(
            :key => "#{key}.rate", :source => key, :value => rate)
        end
      else
        return increment :dropped if @cache.size >= @limit
      end

      increment :received
      @cache[key] = {:key => key, :time => time, :value => value}
    end
  end
end
