require_relative '../processor'
require_relative '../logging'
require_relative '../event'
require_relative '../utils'
require_relative '../reporter'

module FFWD::Processor
  #
  # Implements counting statistics (similar to statsd).
  #
  class CountProcessor
    include FFWD::Logging
    include FFWD::Processor
    include FFWD::Reporter

    register_processor "count"
    setup_reporter(
      :reporter_meta => {:processor => "count"},
      :keys => [:dropped, :received]
    )

    def initialize emitter, opts={}
      @emitter = emitter
      @cache_limit = opts[:cache_limit] || 1000
      @timeout = opts[:timeout] || 300
      @period = opts[:period] || 10
      @cache = {}
      @timer = nil

      starting do
        log.info "Starting count processor on a window of #{@period}s"
      end

      stopping do
        log.info "Stopping count processor"
        @timer.cancel if @timer
        @timer = nil
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

    def check_timer
      return if @timer

      log.debug "Starting timer"

      @timer = EM::Timer.new(@period) do
        @timer = nil
        digest!
      end
    end

    def digest! now
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
        return increment :dropped if @cache.size >= @cache_limit
        entry = @cache[key] = {:count => 0, :last => now}
      end

      increment :received
      entry[:count] += value
      entry[:last] = now
      check_timer
    end
  end
end
