module FFWD
  class Metric < Struct.new(:time, :key, :value, :host, :source, :tags, :attributes)
    def self.make opts={}
      new(opts[:time], opts[:key], opts[:value], opts[:host], opts[:source],
          opts[:tags], opts[:attributes])
    end

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
