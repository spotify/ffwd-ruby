module FFWD::Plugin::Kafka
  # Use a custom attribute for partitioning.
  class AttributeRouter
    DEFAULT_METRIC_PATTERN = "metrics-%s"
    DEFAULT_EVENT_PATTERN = "events-%s"
    DEFAULT_ATTRIBUTE = :site

    def self.build opts
      metric_pattern = opts[:metric_pattern] || DEFAULT_METRIC_PATTERN
      event_pattern = opts[:event_pattern] || DEFAULT_EVENT_PATTERN
      attr = opts[:attribute] || DEFAULT_ATTRIBUTE
      new(metric_pattern, event_pattern, attr)
    end

    def initialize metric_pattern, event_pattern, attr
      @metric_pattern = metric_pattern
      @event_pattern = event_pattern
      @attr = attr.to_sym
      @attr_s = attr.to_s
    end

    def value d
      if v = d.attributes[@attr]
        return v
      end

      d.attributes[@attr_s]
    end
    p
    def route_event e
      return nil unless v = value(e)
      @event_pattern % [v]
    end

    def route_metric m
      return nil unless v = value(m)
      @metric_pattern % [v]
    end
  end

  def self.build_router type, opts
    if type == :attribute
      return AttributeRouter.build opts
    end

    raise "Unsupported router type: #{type}"
  end
end
