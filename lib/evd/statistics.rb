require_relative 'statistics/system_statistics'

module EVD
  module Statistics
    class Collector
      #
      # Initialize the statistics collector.
      # emitter - The emitter used to dispatch metrics for all reporters and
      # statistics collectors.
      # system_channel - A side-channel used by the SystemStatistics component
      # to report information about the system. Messages sent on this channel
      # help Core decide if it should seppuku.
      def initialize emitter, system_channel, opts={}
        @emitter = emitter
        @period = opts[:period] || 1
        @tags = opts[:tags] || []
        @attributes = opts[:attributes] || {}
        @reporters = {}

        system = SystemStatistics.new(system_channel, opts[:system] || {})

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
              :key => "#{id} #{key}", :value => value,
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

    def self.setup emitter, system_channel, opts={}
      Collector.new emitter, system_channel, opts
    end
  end
end
