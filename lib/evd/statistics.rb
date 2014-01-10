module EVD
  module Statistics
    INTERNAL_TAGS = Set.new(['evd'])

    OUT = "evd_output"
    OUT_RATE = "#{OUT}.rate"
    IN = "evd_in"
    IN_RATE = "#{IN}.rate"

    class Collector
      def initialize(core, period, precision)
        @core = core
        @period = period
        @precision = precision
        @in_count = 0
        @out_count = 0
      end

      def input_inc
        @in_count += 1
      end

      def output_inc
        @out_count += 1
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

        in_rate = (@in_count.to_f / diff)
        out_rate = (@out_count.to_f / diff)

        @in_count = @out_count = 0

        @core.emit(:key => IN_RATE, :source => IN,
                   :value => in_rate, :tags => INTERNAL_TAGS)
        @core.emit(:key => OUT_RATE, :source => OUT,
                   :value => out_rate, :tags => INTERNAL_TAGS)
      end
    end

    def self.setup(core, opts)
      period = opts[:period] || 1
      precision = opts[:precision] || 3
      Collector.new(core, period, precision)
    end
  end
end
