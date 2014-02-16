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

    def event_subscribe &block
      @events.subscribe(&block)
    end

    def event event
      @events << event
      increment :events
    end

    def metric_subscribe &block
      @metrics.subscribe(&block)
    end

    def metric metric
      @metrics << metric
      increment :metrics
    end
  end
end
