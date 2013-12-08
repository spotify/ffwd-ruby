module EVD
  module Statistics
    INTERNAL_TAGS = Set.new(['evd'])

    OUTPUT = "evd_output"
    OUTPUT_RATE = "#{OUTPUT}.rate"
    INPUT = "evd_input"
    INPUT_RATE = "#{INPUT}.rate"

    class Collector
      def initialize(core, period, precision)
        @core = core
        @period = period
        @precision = precision
        @input_count = 0
        @output_count = 0
      end

      def input_inc; @input_count += 1; end
      def output_inc; @output_count += 1; end

      def start
        @then = Time.now

        EM::PeriodicTimer.new(@period) do
          generate
        end
      end

      def generate
        now = Time.now
        diff = now - @then

        input_rate = (@input_count.to_f / diff)
        output_rate = (@output_count.to_f / diff)

        @input_count = 0
        @output_count = 0

        input = EVD.event(
          :key => INPUT_RATE, :source => INPUT,
          :value => input_rate, :tags => INTERNAL_TAGS)

        output = EVD.event(
          :key => OUTPUT_RATE, :source => INPUT,
          :value => output_rate, :tags => INTERNAL_TAGS)

        @core.emit input
        @core.emit output

        @then = now
      end
    end

    def self.setup(core, opts)
      period = opts[:period] || 1
      precision = opts[:precision] || 3

      Collector.new(core, period, precision)
    end
  end
end
