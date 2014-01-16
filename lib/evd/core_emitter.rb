require_relative 'utils'
require_relative 'metric'
require_relative 'event'

module EVD
  class CoreEmitter
    def initialize output, opts={}
      @output = output
      @host = opts[:host] || Socket.gethostname
      @tags = Set.new(opts[:tags] || [])
      @attributes = opts[:attributes] || {}
      @ttl = opts[:ttl]
    end

    # Emit an event.
    def emit_event e
      event = EVD.event e

      event.time ||= Time.now
      event.host ||= @host if @host
      event.ttl ||= @ttl if @ttl
      event.tags = EVD.merge_sets @tags, e[:tags]
      event.attributes = EVD.merge_hashes @attributes, e[:attributes]

      @output.event event
    rescue => e
      log.error "Failed to emit event", e
    end

    # Emit a metric.
    def emit_metric m
      metric = EVD.metric m

      metric.time ||= Time.now
      metric.host ||= @host if @host
      metric.tags = EVD.merge_sets @tags, e[:tags]
      metric.attributes = EVD.merge_hashes @attributes, e[:attributes]

      @output.metric metric
    rescue => e
      log.error "Failed to emit metric", e
    end
  end
end
