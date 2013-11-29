require 'evd/data_type'
require 'evd/logging'

module EVD::Type
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
      :p50 => {
        :percentage => 0.50,
        :info => "50th percentile",
      },
      :p95 => {
        :percentage => 0.95,
        :info => "95th percentile",
      },
      :p99 => {
        :percentage => 0.99,
        :info => "99th percentile",
      },
      :p999 => {
        :percentage => 0.999,
        :info => "99.9th percentile",
      },
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
      @times_limit = opts[:times_limit] || 10000
      @precision = opts[:precision] || 3
      @percentiles = opts[:percentiles] || DEFAULT_PERCENTILES

      @_cache = {}
    end

    #
    # Setup all EventMachine hooks.
    #
    def start
      log.info "Setup with flush period #{@flush_period}"

      EventMachine::PeriodicTimer.new(@flush_period) do
        @_cache.each do |key, times|
          calculate(times) do |p, info, value|
            emit :key => "#{key}.#{p}", :source_key => key, :value => value,
                 :description => "#{info} of #{key}"
          end
        end

        @_cache = {}
      end
    end

    def calculate(times)
      total = times.size

      perc_map = {}

      @percentiles.each do |k, v|
        index = (total * v[:percentage]).ceil - 1

        if (config = perc_map[index]).nil?
          config = {:info => v[:info], :percs => []}
          perc_map[index] = config
        end

        percs = config[:percs]

        percs << {:name => k, :value => nil}
      end

      max = nil
      min = nil
      sum = 0.0
      mean = nil

      times.sort.each_with_index do |t, index|
        max = t if max.nil? or t > max
        min = t if min.nil? or t < min
        sum += t

        unless (config = perc_map[index]).nil?
          percs = config[:percs]
          percs.each{|d| d[:value] = t}
        end
      end

      mean = sum / total

      unless @precision.nil?
        max = max.round(@precision)
        min = min.round(@precision)
        sum = sum.round(@precision)
        mean = mean.round(@precision)

        perc_map.each do |index, config|
          percs = config[:percs]
          percs.each{|d| d[:value] = d[:value].round(@precision)}
        end
      end

      yield "max", "Max time", max
      yield "min", "Min time", min
      yield "sum", "Sum", sum
      yield "mean", "Mean", mean

      perc_map.each do |index, config|
        info = config[:info]
        percs = config[:percs]
        percs.each do |d|
          yield d[:name], info, d[:value]
        end
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
        if @_cache.size >= @cache_limit
          log.warning "Dropping cache update '#{key}', limit reached"
          return
        end

        @_cache[key] = times = []
      end

      if times.size >= @times_limit
        log.warning "Dropping times update '#{key}', limit reached"
        return
      end

      value = (value * factor)
      times << value if value >= 0
    end
  end
end
