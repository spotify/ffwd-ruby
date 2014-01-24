require_relative 'logging'
require_relative 'utils'
require_relative 'metric_emitter'
require_relative 'event_emitter'

module FFWD
  class CoreEmitter
    include FFWD::Logging

    def initialize output, opts={}
      @output = output
      @event = EventEmitter.new output, opts, opts[:event] || {}
      @metric = MetricEmitter.new output, opts, opts[:event] || {}
    end

    # Emit an event.
    def emit_event event
      @event.emit event
    rescue => e
      log.error "Failed to emit event", e
    end

    # Emit a metric.
    def emit_metric metric
      @metric.emit metric
    rescue => e
      log.error "Failed to emit metric", e
    end
  end
end
