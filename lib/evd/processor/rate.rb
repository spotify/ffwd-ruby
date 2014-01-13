require 'evd/processor'
require 'evd/logging'

module EVD::Processor
  #
  # Implements rate statistics (similar to derive in collectd).
  #
  class RateProcessor
    include EVD::Logging
    include EVD::Processor

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
    def initialize(opts={})
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
    end

    def start(core)
      unless @ttl.nil?
        EM::PeriodicTimer.new(@ttl) do
          expire!
        end
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

    def report?
      @dropped > 0 or @expired > 0
    end

    def report
      if @dropped > 0
        log.warning "Dropped #{@dropped} event(s)"
        @dropped = 0
      end

      if @expired > 0
        log.warning "Expired #{@expired} event(s)"
        @expired = 0
      end
    end

    def process(core, msg)
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
          core.emit_metric(
            :key => "#{key}.rate", :source => key, :value => rate)
        end
      else
        if @cache.size >= @limit
          @dropped += 1
          return
        end
      end

      @cache[key] = {:key => key, :time => time, :value => value}
    end
  end
end
