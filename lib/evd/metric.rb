module EVD
  Metric = Struct.new(
    :time,
    :key,
    :value,
    :host,
    :source,
    :tags,
    :attributes
  )

  def self.metric(opts = {})
    Metric.new(
      opts[:time],
      opts[:key],
      opts[:value],
      opts[:host],
      opts[:source],
      opts[:tags],
      opts[:attributes]
    )
  end

  def self.metric_to_h(e)
    d = {}
    d[:time] = e.time.to_i if e.time
    d[:key] = e.key if e.key
    d[:value] = e.value if e.value
    d[:host] = e.host if e.host
    d[:source] = e.source if e.source
    d[:tags] = e.tags.to_a if e.tags
    d[:attributes] = e.attributes if e.attributes
    d
  end
end
