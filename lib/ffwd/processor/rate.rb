require 'ffwd/processor'
require 'ffwd/logging'

module FFWD::Processor
  #
  # Implements rate statistics (similar to derive in collectd).
  #
  class RateProcessor
    include FFWD::Logging
    include FFWD::Processor

    register_type "rate"

    # Options:
    #
    # :precision - The precision to round to for emitted values.
    # :cache_limit - Maxiumum amount of items allowed in the cache.
    # :min_age - Minimum age that an item has to have in the cache to calculate
    # rates.
    # This exists to prevent too frequent updates to the cache which would
    # yield very static or jumpy rates.
    # Can be set to null to disable.
    # :ttl - Allowed age of items in cache in seconds.
    # If this is nil, items will never expire, so old elements will not be
    # expunged until data type is restarted.
    def initialize emitter, opts={}
      @emitter = emitter

      @precision = opts[:precision] || 3
      @limit = opts[:cache_limit] || 10000
      @min_age = opts[:min_age] || 0.5
      @ttl = opts[:ttl] || 600
      # keep a reference to the expire cache to prevent having to allocate it
      # all the time.
      @expire = Hash.new
      # Cache of active events.
      @cache = Hash.new

      # Amount of events dropped, log during 'report'.
      @dropped = 0
      @expired = 0
      @received = 0
    end

    def start
      return if @ttl.nil?

      log.info "Expiring cache every #{@ttl}s"

      timer = EM::PeriodicTimer.new(@ttl) do
        expire!
      end

      stopping do
        timer.cancel
      end
    end

    # Expire cached events that are too old.
    def expire!
      now = Time.new

      @cache.each do |key, value|
        diff = (now - value[:time])
        next if diff < @ttl
        @expire[key] = value
      end

      unless @expire.empty?
        @expired += @cache.size - @expire.size
        @cache = @expire
        @expire = Hash.new
      end
    end

    def report
      yield "processor-rate/dropped", @dropped
      yield "processor-rate/expired", @expired
      yield "processor-rate/received", @received

      @dropped = 0
      @expired = 0
      @received = 0
    end

    def process msg
      key = msg[:key]
      time = msg[:time]
      value = msg[:value] || 0

      unless (prev = @cache[key]).nil?
        prev_time = prev[:time]
        prev_value = prev[:value]

        diff = (time - prev_time)

        valid = @ttl.nil? or diff < @ttl
        aged = @min_age.nil? or diff > @min_age

        if diff > 0 and valid and aged
          rate = ((value - prev_value) / diff)
          rate = rate.round(@precision) unless @precision.nil?
          @emitter.emit_metric(
            :key => "#{key}.rate", :source => key, :value => rate)
        end
      else
        if @cache.size >= @limit
          @dropped += 1
          return
        end
      end

      @received += 1
      @cache[key] = {:key => key, :time => time, :value => value}
    end
  end
end
