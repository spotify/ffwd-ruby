require 'ffwd/event'
require 'ffwd/logging'
require 'ffwd/processor'
require 'ffwd/reporter'

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
      :p50 => {:percentage => 0.50, :info => "50th"},
      :p75 => {:percentage => 0.75, :info => "75th"},
      :p95 => {:percentage => 0.95, :info => "95th"},
      :p99 => {:percentage => 0.99, :info => "99th"},
      :p999 => {:percentage => 0.999, :info => "99.9th"},
    }

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
    #   {:p10 => {:info => "Some description", :percentage => 0.1}, ...}
    def initialize emitter, opts={}
      @emitter = emitter

      @window = opts[:window] || 10
      @cache_limit = opts[:cache_limit] || 1000
      @bucket_limit = opts[:bucket_limit] || 10000
      @precision = opts[:precision] || 3
      @missing = opts[:missing] || DEFAULT_MISSING
      @percentiles = opts[:percentiles] || DEFAULT_PERCENTILES

      # Dropped values that would have gone into a bucket.
      @cache = {}

      starting do
        log.info "Starting histogram processor on a window of #{@window}s"
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

      @timer = EM.add_timer(@window) do
        @timer = nil
        digest!
      end
    end

    # Digest the cache.
    def digest!
      if @cache.empty?
        return
      end

      ms = FFWD.timer do
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
        index = (total * v[:percentage]).ceil - 1

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
