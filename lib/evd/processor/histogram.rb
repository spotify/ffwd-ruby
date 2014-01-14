require 'evd/processor'
require 'evd/logging'
require 'evd/event'

module EVD::Processor
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
    include EVD::Processor
    include EVD::Logging

    register_type "histogram"

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
    def initialize opts={}
      @window = opts[:window] || 10
      @cache_limit = opts[:cache_limit] || 1000
      @bucket_limit = opts[:bucket_limit] || 10000
      @precision = opts[:precision] || 3

      @missing = opts[:missing] || DEFAULT_MISSING
      @percentiles = opts[:percentiles] || DEFAULT_PERCENTILES

      # Dropped values.
      @dropped = 0

      # Dropped values that would have gone into a bucket.
      @bucket_dropped = 0

      @cache = {}
    end

    def report?
      @dropped > 0 or @bucket_dropped > 0
    end

    def report
      if @dropped > 0
        log.warning "Dropped #{@dropped} event(s)"
        @dropped = 0
      end

      if @bucket_dropped > 0
        log.warning "Dropped #{@bucket_dropped} bucket value(s)"
        @bucket_dropped = 0
      end
    end

    # Setup all EventMachine hooks.
    def start emitter
      log.info "Digesting on a window of #{@window}s"

      EM::PeriodicTimer.new(@window) do
        digest! emitter
      end
    end

    # Digest the cache.
    def digest! emitter
      if @cache.empty?
        return
      end

      @cache.each do |key, bucket|
        calculate(bucket) do |p, info, value|
          emitter.emit_metric(
            :key => "#{key}.#{p}", :source => key,
            :value => value, :description => "#{info} of #{key}")
        end
      end

      @cache = {}
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

    def process emitter, m
      key = m[:key]
      value = m[:value] || @missing

      if (bucket = @cache[key]).nil?
        if @cache.size >= @cache_limit
          @dropped += 1
          return
        end

        @cache[key] = bucket = []
      end

      if bucket.size >= @bucket_limit
        @bucket_dropped += 1
        return
      end

      bucket << value
    end
  end
end
