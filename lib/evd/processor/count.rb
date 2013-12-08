require 'evd/processor'
require 'evd/logging'
require 'evd/event'

module EVD::Processor
  #
  # Implements counting statistics (similar to statsd).
  #
  class CountProcessor
    include EVD::Logging
    include EVD::Processor

    register_type "count"

    def initialize(opts={})
      @cache_limit = opts[:cache_limit] || 10000
      @_cache = {}
    end

    def process(core, m)
      key = m[:key]
      value = m[:value]

      unless (prev_value = @_cache[key]).nil?
        value = prev_value + value
      else
        if @_cache.size >= @cache_limit
          log.warning "Dropping cache update '#{key}', limit reached"
          return
        end
      end

      @_cache[key] = value
      core.emit :key => key, :value => value, :source => key
    end
  end
end
