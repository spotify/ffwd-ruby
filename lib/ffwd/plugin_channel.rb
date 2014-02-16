require_relative 'lifecycle'
require_relative 'logging'
require_relative 'reporter'

module FFWD
  # A set of channels, one for metrics and one for events.
  # This is simply a convenience class to group the channel that are available
  # to a plugin in one direction (usually either input or output).
  class PluginChannel
    include FFWD::Lifecycle
    include FFWD::Reporter
    include FFWD::Logging

    setup_reporter :keys => [:metrics, :events]

    attr_reader :reporter_meta, :events, :metrics, :name

    def self.build name
      events = FFWD::Channel.new log, "#{name}.events"
      metrics = FFWD::Channel.new log, "#{name}.metrics"
      new name, metrics, events
    end

    def initialize name, events, metrics
      @name = name
      @events = events
      @metrics = metrics
      @reporter_meta = {:name => @name, :type => "plugin_channel"}
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
      increment :events
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
      increment :metrics
    end
  end
end
