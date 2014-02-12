module FFWD
  # Struct used to define all fields related to an event.
  EventStruct = Struct.new(
    # The time at which the event was collected.
    :time,
    # The unique key of the event.
    :key,
    # A numeric value associated with the event.
    :value,
    # The host from which the event originated.
    :host,
    # The source event this event was derived from (if any).
    :source,
    # A state associated to the event.
    :state,
    # A description associated to the event.
    :description,
    # A time to live associated with the event.
    :ttl,
    # Tags associated with the event.
    :tags,
    # Attributes (extra fields) associated with the event.
    :attributes
  )

  # A convenience class for each individual event.
  class Event < EventStruct
    def self.make opts = {}
      new(opts[:time], opts[:key], opts[:value], opts[:host], opts[:source],
          opts[:state], opts[:description], opts[:ttl], opts[:tags],
          opts[:attributes])
    end

    # Convert event to a sparse hash.
    def to_h
      d = {}
      d[:time] = time.to_i if time
      d[:key] = key if key
      d[:value] = value if value
      d[:host] = host if host
      d[:source] = source if source
      d[:state] = state if state
      d[:description] = description if description
      d[:ttl] = ttl if ttl
      d[:tags] = tags.to_a if tags
      d[:attributes] = attributes if attributes
      d
    end
  end
end
