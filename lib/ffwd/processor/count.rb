require_relative '../processor'
require_relative '../logging'
require_relative '../event'
require_relative '../utils'

module FFWD::Processor
  #
  # Implements counting statistics (similar to statsd).
  #
  class CountProcessor
    include FFWD::Logging
    include FFWD::Processor

    register_type "count"

    def initialize emitter, opts={}
      @emitter = emitter
      @cache_limit = opts[:cache_limit] || 1000
      @timeout = opts[:timeout] || 300
      @period = opts[:period] || 10
      @cache = {}
      @timer = nil

      starting do
        log.info "Starting count processor"

        @timer = EM::PeriodicTimer.new(@period) do
          now = Time.now
          flush! now
        end
      end

      stopping do
        log.info "Stopping count processor"

        if @timer
          @timer.cancel
          @timer = nil
        end
      end
    end

    def flush_caches! now
      @cache.each do |key, entry|
        count = entry[:count]
        last = entry[:last]

        if now - last > @timeout
          @cache.delete key
          next
        end

        entry[:count] = 0

        @emitter.metric.emit(
          :key => "#{key}.sum", :value => count, :source => key)
      end
    end

    def flush! now
      ms = FFWD.timing do
        flush_caches! now
      end

      log.debug "Digest took #{ms}ms"
    end

    def process m
      key = m[:key]
      value = m[:value]

      now = Time.now

      unless (entry = @cache[key])
        if @cache.size < @cache_limit
          entry = @cache[key] = {:count => value, :last => now}
        else
          log.warning "Dropping cache update '#{key}', limit reached."
          return
        end
      end

      entry[:count] += value
      entry[:last] = now
    end
  end
end
