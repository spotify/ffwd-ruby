require_relative 'logging'

module EVD
  # A set of channels, one for metrics and one for events.
  # This is simply a convenience class to group the channel that are available
  # to a plugin in one direction (usually either input or output).
  #
  # 'kind' is available to designate the type of the channel.
  class PluginChannel
    include EVD::Logging

    def initialize kind
      @kind = kind

      @metrics = EVD::Channel.new(log, "#{kind}.metrics")
      @events = EVD::Channel.new(log, "#{kind}.events")

      @metric_count = 0
      @event_count = 0
    end

    def kind
      @kind
    end

    # fetch and reset statistics.
    def stats!
      d = {:metrics => @metric_count, :events => @event_count}
      @metric_count = @event_count = 0
      return d
    end

    def metric metric
      @metrics << metric
      @metric_count += 1
    end

    def metric_subscribe
      @metrics.subscribe do |metric|
        yield metric
        @metric_count += 1
      end
    end

    def metric_unsubscribe id
      @metrics.unsubscribe id
    end

    def event event
      @events << event
      @event_count += 1
    end

    def event_subscribe
      @events.subscribe do |event|
        yield event
      end
    end

    def event_unsubscribe id
      @events.unsubscribe id
    end
  end
end
