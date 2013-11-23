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

    DEFAULT_PERCENTILES = {
      :p50 => 0.50,
      :p95 => 0.95,
      :p99 => 0.99,
      :p999 => 0.999,
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
      @precision = opts[:precision] || 3
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

    def calculate(times, percentiles=DEFAULT_PERCENTILES)
      total = times.size

      perc_map = Hash[percentiles.map{
        |k, v| [(total * v).ceil - 1, {:name => k, :value => nil}]}
      ]

      max = nil
      min = nil
      sum = 0.0
      mean = nil

      times.sort.each_with_index do |t, i|
        max = t if max.nil? or t > max
        min = t if min.nil? or t < min
        sum += t

        unless perc_map[i].nil?
          perc_map[i][:value] = t
        end
      end

      mean = sum / total

      unless @precision.nil?
        max = max.round(@precision)
        min = min.round(@precision)
        sum = sum.round(@precision)
        mean = mean.round(@precision)

        perc_map.each do |i, d|
          d[:value] = d[:value].round(@precision)
        end
      end

      yield "max", max
      yield "min", min
      yield "sum", sum
      yield "mean", mean

      perc_map.each do |name, d|
        yield d[:name], d[:value]
      end
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
        if @_cache.size > @cache_limit
          log.warning "Dropping '#{key}': #{@_cache.size} > #{@cache_limit}"
          return
        end

        @_cache[key] = times = []
      end

      if times.size > @times_limit
        log.warning "Dropping update '#{key}': #{times.size} > #{@times_limit}"
        return
      end

      value = (value * factor)
      times << value if value >= 0
    end
  end
end
