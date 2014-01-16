module EVD
  module Statistics
    INTERNAL_TAGS = Set.new(['evd'])

    class Collector
      def initialize(emitter, channels, period, precision)
        @emitter = emitter
        @channels = channels
        @period = period
        @precision = precision
      end

      def start
        @last = Time.now

        EM::PeriodicTimer.new(@period) do
          now = Time.now
          generate! @last, now
          @last = now
        end
      end

      def generate! last, now
        diff = now - last

        @channels.each do |channel|
          stats = channel.stats!

          stats.each do |k, v|
            rate = v.to_f / diff
            source = "#{channel.kind}.#{k.to_s}"
            key = "#{source}.rate"
            @emitter.emit_metric(
              :key => key, :source => source, :value => rate,
              :tags => INTERNAL_TAGS
            )
          end
        end
      end
    end

    def self.setup emitter, channels, opts
      period = opts[:period] || 1
      precision = opts[:precision] || 3
      Collector.new emitter, channels, period, precision
    end
  end
end
