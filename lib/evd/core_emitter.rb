require_relative 'utils'
require_relative 'metric'
require_relative 'event'
require_relative 'logging'

module EVD
  class CoreEmitter
    include EVD::Logging

    def initialize output, opts={}
      @output = output
      @host = opts[:host] || Socket.gethostname
      @tags = Set.new(opts[:tags] || [])
      @attributes = opts[:attributes] || {}
      @ttl = opts[:ttl]

      @metric_tags, @metric_attributes = make_metadata(
        @tags, @attributes, opts[:metric])

      @event_tags, @event_attributes = make_metadata(
        @tags, @attributes, opts[:metric])
    end

    def make_metadata tags, attributes, opts
      if opts
        [(tags + (opts[:tags] || [])),
         (attributes.merge(opts[:attributes] || {}))]
      else
        [tags, attributes]
      end
    end

    # Emit an event.
    def emit_event event
      event = EVD.event event

      event.time ||= Time.now
      event.host ||= @host if @host
      event.ttl ||= @ttl if @ttl
      event.tags = EVD.merge_sets @metric_tags, event[:tags]
      event.attributes = EVD.merge_hashes @metric_attributes, event[:attributes]

      @output.event event
    rescue => e
      log.error "Failed to emit event", e
    end

    # Emit a metric.
    def emit_metric metric
      metric = EVD.metric metric

      metric.time ||= Time.now
      metric.host ||= @host if @host
      metric.tags = EVD.merge_sets @event_tags, metric[:tags]
      metric.attributes = EVD.merge_hashes @event_attributes, metric[:attributes]

      @output.metric metric
    rescue => e
      log.error "Failed to emit metric", e
    end
  end
end
