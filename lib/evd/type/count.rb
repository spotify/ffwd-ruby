require 'evd/logging'
require 'evd/data_type'

module EVD::Type
  #
  # Implements counting statistics (similar to statsd).
  #
  class Count
    include EVD::Logging
    include EVD::DataType

    register_type "count"

    def initialize(opts={})
      @cache_limit = opts[:cache_limit] || 10000
      @_cache = {}
    end

    def process(msg)
      key = msg[:key]
      value = msg[:value]

      unless (prev_value = @_cache[key]).nil?
        value = prev_value + value
      else
        if @_cache.size >= @cache_limit
          log.warning "Dropping cache update '#{key}', limit reached"
          return
        end
      end

      @_cache[key] = value
      emit(msg.merge(:value => value))
    end
  end
end
