module EVD
  Event = Struct.new(
    :key,
    :value,
    :host,
    :source,
    :state, :description,
    :ttl, :time,
    :tags, :attributes)

  def self.event(opts = {})
    Event.new(
      opts[:key],
      opts[:value],
      opts[:host],
      opts[:source],
      opts[:state],
      opts[:description],
      opts[:ttl],
      opts[:time],
      opts[:tags],
      opts[:attributes])
  end
end
