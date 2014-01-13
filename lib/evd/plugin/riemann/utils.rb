module EVD::Plugin::Riemann
  MAPPING = [
    [:key, :service, :service=],
    [:value, :metric, :metric=],
    [:host, :host, :host=],
  ]

  METRIC_MAPPING = MAPPING

  EVENT_MAPPING = [
    [:state, :state, :state=],
    [:description, :description, :description=],
    [:ttl, :ttl, :ttl=],
  ] + MAPPING

  module Utils
    def read_attributes e, source
      return if source.nil? or source.empty?

      attributes = Hash[source.each do |a|
        [a.key, a.value]
      end]

      e[:attributes] = attributes
    end

    def write_attributes e, source
      return if source.nil? or source.empty?

      e.attributes = source.map{|k, v|
        ::Riemann::Attribute.new(:key => k.dup, :value => v.dup)
      }
    end

    def read_tags e, source
      return if source.nil? or source.empty?
      e[:tags] = Set.new source
    end

    def write_tags e, source
      return if source.nil? or source.empty?
      e.tags = source.map{|v| v.dup}
    end

    def read_time e, source
      return if source.nil?
      e[:time] = Time.at source
    end

    def write_time e, source
      return if source.nil?
      e.time = source.to_i
    end

    def make_event event
      e = ::Riemann::Event.new

      write_attributes e, event.attributes
      write_tags e, event.tags
      write_time e, event.time

      EVENT_MAPPING.each do |key, reader, writer|
        if (v = event.send(key)).nil?
          next
        end

        e.send writer, v
      end

      e
    end

    def make_metric metric
      e = ::Riemann::Event.new

      write_attributes e, metric.attributes
      write_tags e, metric.tags
      write_time e, metric.time

      METRIC_MAPPING.each do |key, reader, writer|
        if (v = metric.send(key)).nil?
          next
        end

        e.send writer, v
      end

      e
    end

    def read_event event
      e = {}

      read_attributes e, event.attributes
      read_tags e, event.tags
      read_time e, event.time

      EVENT_MAPPING.each do |key, reader, writer|
        if (v = event.send(reader)).nil?
          next
        end

        e[key] = v
      end

      e
    end

    def make_message(message)
      ::Riemann::Message.new(message)
    end

    def read_message(data)
      ::Riemann::Message.decode data
    end
  end
end
