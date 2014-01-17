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
    end

    # Emit an event.
    def emit_event event
      event = EVD.event event

      event.time ||= Time.now
      event.host ||= @host if @host
      event.ttl ||= @ttl if @ttl
      event.tags = EVD.merge_sets @tags, event[:tags]
      event.attributes = EVD.merge_hashes @attributes, event[:attributes]

      @output.event event
    rescue => e
      log.error "Failed to emit event", e
    end

    # Emit a metric.
    def emit_metric metric
      metric = EVD.metric metric

      metric.time ||= Time.now
      metric.host ||= @host if @host
      metric.tags = EVD.merge_sets @tags, metric[:tags]
      metric.attributes = EVD.merge_hashes @attributes, metric[:attributes]

      @output.metric metric
    rescue => e
      log.error "Failed to emit metric", e
    end
  end
end
