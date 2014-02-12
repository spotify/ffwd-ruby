module FFWD
  # Struct used to define all fields related to a metric.
  MetricStruct = Struct.new(
    # The time at which the metric was collected.
    :time,
    # The unique key of the metric.
    :key,
    # A numeric value associated with the metric.
    :value,
    # The host from which the metric originated.
    :host,
    # The source metric this metric was derived from (if any).
    :source,
    # Tags associated to the metric.
    :tags,
    # Attributes (extra fields) associated to the metric.
    :attributes
  )

  # A convenience class for each individual metric.
  class Metric < MetricStruct
    def self.make opts={}
      new(opts[:time], opts[:key], opts[:value], opts[:host], opts[:source],
          opts[:tags], opts[:attributes])
    end

    # Convert metric to a sparse hash.
    def to_h
      d = {}
      d[:time] = time.to_i if time
      d[:key] = key if key
      d[:value] = value if value
      d[:host] = host if host
      d[:source] = source if source
      d[:tags] = tags.to_a if tags
      d[:attributes] = attributes if attributes
      d
    end
  end
end
