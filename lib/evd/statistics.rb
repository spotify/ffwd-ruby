require_relative 'statistics/system_statistics'
require_relative 'statistics/channel_statistics'

module EVD
  module Statistics
    class Collector
      def initialize emitter, channels, opts={}
        @emitter = emitter
        @period = opts[:period] || 1
        @tags = opts[:tags] || []
        @attributes = opts[:attributes] || {}
        @reporters = {}

        @channel = ChannelStatistics.new(channels, opts[:channel] || {})

        if (system = SystemStatistics.new(opts[:system] || {})).check
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
        @channel.collect(last, now) do |key, value|
          @emitter.emit_metric(
            :key => key, :value => value,
            :tags => @tags, :attributes => @attributes)
        end

        if @system
          @system.collect do |key, value|
            @emitter.emit_metric(
              :key => key, :value => value,
              :tags => @tags, :attributes => @attributes)
          end
        end

        @reporters.each do |id, reporter|
          reporter.collect do |key, value|
            @emitter.emit_metric(
              :key => "#{id} #{key} count", :value => value,
              :tags => @tags, :attributes => @attributes)
          end
        end
      end

      def register id, reporter
        @reporters[id] = reporter
      end

      def unregister id
        @reporters.delete id
      end
    end

    def self.setup emitter, channels, opts={}
      Collector.new emitter, channels, opts
    end
  end
end
