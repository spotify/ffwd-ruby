require_relative 'logging'
require_relative 'lifecycle'

module FFWD
  # A set of channels, one for metrics and one for events.
  # This is simply a convenience class to group the channel that are available
  # to a plugin in one direction (usually either input or output).
  class PluginChannel
    include FFWD::Lifecycle
    include FFWD::Logging

    attr_reader :name

    def self.build name
      events = FFWD::Channel.new log, "#{name}.events"
      metrics = FFWD::Channel.new log, "#{name}.metrics"
      new name, metrics, events
    end

    def initialize name, events, metrics
      @name = name
      @events = events
      @metrics = metrics
      @metric_count = 0
      @event_count = 0
    end

    def report
      yield "plugin_channel-#{@name}/metrics", @metric_count
      yield "plugin_channel-#{@name}/events", @event_count
      @metric_count = @event_count = 0
    end

    def event_subscribe
      @events.subscribe do |event|
        yield event
      end
    end

    def event_unsubscribe id
      @events.unsubscribe id
    end

    def event event
      @events << event
      @event_count += 1
    end

    def metric_subscribe
      @metrics.subscribe do |metric|
        yield metric
      end
    end

    def metric_unsubscribe id
      @metrics.unsubscribe id
    end

    def metric metric
      @metrics << metric
      @metric_count += 1
    end
  end
end
