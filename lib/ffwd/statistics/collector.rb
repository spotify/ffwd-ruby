require_relative '../lifecycle'

require_relative 'system_statistics'

module FFWD::Statistics
  class Collector
    include FFWD::Lifecycle

    DEFAULT_PERIOD = 10

    # Initialize the statistics collector.
    #
    # emitter - The emitter used to dispatch metrics for all reporters and
    # statistics collectors.
    # channel - A side-channel used by the SystemStatistics component
    # to report information about the system. Messages sent on this channel
    # help Core decide if it should seppuku.
    def initialize log, emitter, channel, opts={}
      @emitter = emitter
      @period = opts[:period] || DEFAULT_PERIOD
      @tags = opts[:tags] || []
      @attributes = opts[:attributes] || {}
      @reporters = {}
      @channel = channel
      @timer = nil

      system = SystemStatistics.new(opts[:system] || {})

      if system.check
        @system = system
      else
        @system = nil
      end

      starting do
        log.info "Started statistics collection"

        @last = Time.now

        @timer = EM::PeriodicTimer.new @period do
          now = Time.now
          generate! @last, now
          @last = now
        end
      end

      stopping do
        log.info "Stopped statistics collection"

        if @timer
          @timer.cancel
          @timer = nil
        end
      end
    end

    def generate! last, now
      if @system
        @system.collect @channel do |key, value|
          @emitter.metric.emit(
            :key => key, :value => value,
            :tags => @tags, :attributes => @attributes)
        end
      end

      @reporters.each do |id, reporter|
        reporter.report! do |key, value|
          @emitter.metric.emit(
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
end
