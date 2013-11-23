require 'evd/data_type'
require 'evd/logging'

module EVD
  #
  # Implements timing statistics (similar to statsd).
  #
  # Timing statistics receives 'times' continiuosly and regularly flushes out
  # the following statistics.
  #
  # max - Max timing collected.
  # min - Min timing collected.
  # mean - Mean timing collected.
  # p50 - The 50th percentile time collected.
  # p95 - The 95th percentile time collected.
  # p99 - The 99th percentile time collected.
  # p999 - The 99.9th percentile time collected.
  #
  class Timing
    include EVD::DataType
    include EVD::Logging

    register_type "timing"

    UNITS = {
      "ms" => 1,
      "s" => 1000,
      "m" => 1000 * 60,
      "h" => 1000 * 3600,
    }

    #
    # Options:
    #
    # flush_period - Define at what period the cache is flushed and generates
    # metrics.
    # cache_limit - Limit the amount of cache entries (by key).
    # times_limit - Limit the amount of limits for each cache entry.
    #
    def initialize(opts={})
      @flush_period = opts[:flush_period] || 10
      @cache_limit = opts[:cache_limit] || 1000
      @times_limit = opts[:times_limit] || 1000
      @_cache = {}
    end

    #
    # Setup all EventMachine hooks.
    #
    def setup
      log.info "Setup with flush period #{@flush_period}"

      EventMachine::PeriodicTimer.new(@flush_period) do
        @_cache.each do |key, times|
          calculate(times) do |p, value|
            emit(:key => "#{key}.#{p}", :value => value)
          end
        end

        @_cache = {}
      end
    end

    def calculate(times)
      total = times.size

      n50 = (total * 0.50).ceil - 1
      n95 = (total * 0.95).ceil - 1
      n99 = (total * 0.99).ceil - 1
      n999 = (total * 0.999).ceil - 1

      max = nil
      min = nil
      sum = 0.0
      mean = nil

      p50 = nil
      p95 = nil
      p99 = nil
      p999 = nil

      times.sort.each_with_index do |time, i|
        max = time if max.nil? or time > max
        min = time if min.nil? or time < min
        sum += time
        p50 = time if i == n50
        p95 = time if i == n95
        p99 = time if i == n99
        p999 = time if i == n999
      end

      mean = sum / total

      yield "max", max
      yield "min", min
      yield "sum", sum
      yield "mean", mean
      yield "p50", p50
      yield "p95", p95
      yield "p99", p99
      yield "p999", p999
    end

    def parse_unit(unit)
      factor = UNITS[unit.downcase]
      raise Exception.new("Unknown unit: #{unit}") if factor.nil?
      factor
    end

    def process(msg)
      key = msg[:key]
      value = msg[:value] || 0
      time = msg[:time]
      factor = parse_unit(msg[:unit] || "ms")

      if (times = @_cache[key]).nil?
        return if @_cache.size > @cache_limit
        @_cache[key] = times = []
      end

      return if times.size > @times_limit

      value = (value * factor)
      times << value if value >= 0
    end
  end
end
