module FFWD
  Event = Struct.new(
    :time,
    :key,
    :value,
    :host,
    :source,
    :state,
    :description,
    :ttl,
    :tags,
    :attributes
  )

  def self.event(opts = {})
    Event.new(
      opts[:time],
      opts[:key],
      opts[:value],
      opts[:host],
      opts[:source],
      opts[:state],
      opts[:description],
      opts[:ttl],
      opts[:tags],
      opts[:attributes]
    )
  end

  def self.event_to_h(e)
    d = {}
    d[:time] = e.time.to_i if e.time
    d[:key] = e.key if e.key
    d[:value] = e.value if e.value
    d[:host] = e.host if e.host
    d[:source] = e.source if e.source
    d[:state] = e.state if e.state
    d[:description] = e.description if e.description
    d[:ttl] = e.ttl if e.ttl
    d[:tags] = e.tags.to_a if e.tags
    d[:attributes] = e.attributes if e.attributes
    d
  end
end
