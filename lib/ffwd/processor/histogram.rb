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

require 'ffwd/event'
require 'ffwd/logging'
require 'ffwd/processor'
require 'ffwd/reporter'
require 'ffwd/utils'

module FFWD::Processor
  #
  # Implements histogram statistics over a tumbling time window.
  #
  # Histogram received metrics continiuosly and regularly flushes out the
  # following statistics.
  #
  # <key>.min - Min value collected.
  # <key>.max - Max value collected.
  # <key>.mean - Mean value collected.
  # <key>.p50 - The 50th percentile value collected.
  # <key>.p75 - The 75th percentile value collected.
  # <key>.p95 - The 95th percentile value collected.
  # <key>.p99 - The 99th percentile value collected.
  # <key>.p999 - The 99.9th percentile value collected.
  #
  class HistogramProcessor
    include FFWD::Processor
    include FFWD::Logging
    include FFWD::Reporter

    register_processor "histogram"
    setup_reporter(
      :reporter_meta => {:processor => "histogram"},
      :keys => [:dropped, :bucket_dropped, :received]
    )

    DEFAULT_MISSING = 0

    DEFAULT_PERCENTILES = {
      :p50 => {:q => 0.50, :info => "50th"},
      :p75 => {:q => 0.75, :info => "75th"},
      :p95 => {:q => 0.95, :info => "95th"},
      :p99 => {:q => 0.99, :info => "99th"},
      :p999 => {:q => 0.999, :info => "99.9th"},
    }

    def self.prepare config
      config[:window] ||= 10
      config[:cache_limit] ||= 1000
      config[:bucket_limit] ||= 10000
      config[:precision] ||= 3
      config[:missing] ||= DEFAULT_MISSING
      config[:percentiles] ||= DEFAULT_PERCENTILES
      config
    end

    #
    # Options:
    #
    # :window - Define at what period the cache is flushed and generates
    # metrics.
    # :cache_limit - Limit the amount of cache entries (by key).
    # :bucket_limit - Limit the amount of limits for each cache entry.
    # :precision - Precision of emitted metrics.
    # :percentiles - Configuration hash of percentile metrics.
    # Structure:
    #   {:p10 => {:info => "Some description", :q => 0.1}, ...}
    def initialize emitter, config={}
      @emitter = emitter

      @window = config[:window]
      @cache_limit = config[:cache_limit]
      @bucket_limit = config[:bucket_limit]
      @precision = config[:precision]
      @missing = config[:missing]
      @percentiles = config[:percentiles]

      # Dropped values that would have gone into a bucket.
      @cache = {}

      starting do
        log.info "Started"
        log.info "  config: #{config.inspect}"
      end

      stopping do
        log.info "Stopping histogram processor"
        @timer.cancel if @timer
        @timer = nil
        digest!
      end
    end

    def check_timer
      return if @timer

      log.debug "Starting timer"

      @timer = EM::Timer.new(@window) do
        @timer = nil
        digest!
      end
    end

    # Digest the cache.
    def digest!
      if @cache.empty?
        return
      end

      ms = FFWD.timing do
        @cache.each do |key, bucket|
          calculate(bucket) do |p, info, value|
            @emitter.metric.emit(
              :key => "#{key}.#{p}", :source => key,
              :value => value, :description => "#{info} of #{key}")
          end
        end

        @cache = {}
      end

      log.debug "Digest took #{ms}ms"
    end

    def calculate bucket
      total = bucket.size

      map = {}

      @percentiles.each do |k, v|
        index = (total * v[:q]).ceil - 1

        if (c = map[index]).nil?
          info = "#{v[:info]} percentile"
          c = map[index] = {:info => info, :values => []}
        end

        c[:values] << {:name => k, :value => nil}
      end

      max = nil
      min = nil
      sum = 0.0
      mean = nil

      bucket.sort.each_with_index do |t, index|
        max = t if max.nil? or t > max
        min = t if min.nil? or t < min
        sum += t

        unless (c = map[index]).nil?
          c[:values].each{|d| d[:value] = t}
        end
      end

      mean = sum / total

      unless @precision.nil?
        max = max.round(@precision)
        min = min.round(@precision)
        sum = sum.round(@precision)
        mean = mean.round(@precision)

        map.each do |index, c|
          c[:values].each{|d| d[:value] = d[:value].round(@precision)}
        end
      end

      yield "max", "Max", max
      yield "min", "Min", min
      yield "sum", "Sum", sum
      yield "mean", "Mean", mean

      map.each do |index, c|
        c[:values].each do |d|
          yield d[:name], c[:info], d[:value]
        end
      end
    end

    def process m
      key = m[:key]
      value = m[:value] || @missing

      if (bucket = @cache[key]).nil?
        return increment :dropped if @cache.size >= @cache_limit
        @cache[key] = bucket = []
      end

      return increment :bucket_dropped if bucket.size >= @bucket_limit
      return increment :dropped if stopped?
      increment :received

      bucket << value
      check_timer
    end
  end
end
