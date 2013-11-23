require 'evd/logging'
require 'evd/data_type'

module EVD
  #
  # Implements rate statistics (similar to derive in collectd).
  #
  class Rate
    include EVD::Logging
    include EVD::DataType

    register_type "rate"

    def initialize(opts={})
      @precision = opts[:precision] || 3
      @cache_limit = opts[:cache_limit] || 10000
      @_cache = {}
    end

    def process(msg)
      key = msg[:key]
      current_time = msg[:time]
      current_value = msg[:value] || 0

      unless (prev = @_cache[key]).nil?
        prev_time = prev[:time]
        prev_value = prev[:value]

        difference = (current_time - prev_time)

        if difference > 0
          rate = ((current_value - prev_value) / difference)
          rate = rate.round(@precision) unless @precision.nil?
          emit(:key => "#{key}.rate", :value => rate)
        end
      else
        if @_cache.size > @cache_limit
          log.warning "Dropping '#{key}': #{@_cache.size} > #{@cache_limit}"
          return
        end
      end

      @_cache[key] = msg
    end
  end
end
