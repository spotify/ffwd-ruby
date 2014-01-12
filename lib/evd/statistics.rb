module EVD
  module Statistics
    INTERNAL_TAGS = Set.new(['evd'])

    class Collector
      def initialize(core, channels, period, precision)
        @core = core
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
            @core.emit_metric(
              {:key => key, :source => source, :value => rate},
              INTERNAL_TAGS
            )
          end
        end
      end
    end

    def self.setup(core, channels, opts)
      period = opts[:period] || 1
      precision = opts[:precision] || 3
      Collector.new core, channels, period, precision
    end
  end
end
