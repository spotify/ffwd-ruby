require_relative 'statistics/system_statistics'

module EVD
  module Statistics
    class Collector
      def initialize emitter, channels, opts={}
        @emitter = emitter
        @channels = channels
        @period = opts[:period] || 1
        @precision = opts[:precision] || 3
        @tags = opts[:tags] || []
        @attributes = opts[:attributes] || {}
        system = SystemStatistics.new(opts[:system] || {})

        if system.check
          @system = system
        else
          @system = nil
        end
      end

      def start
        @last = Time.now

        EM::PeriodicTimer.new @period do
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
              :tags => @tags, :attributes => @attributes)
          end
        end

        if @system
          @system.collect.each do |key, value|
            @emitter.emit_metric(
              :key => key, :value => value,
              :tags => @tags, :attributes => @attributes)
          end
        end
      end
    end

    def self.setup emitter, channels, opts={}
      Collector.new emitter, channels, opts
    end
  end
end
