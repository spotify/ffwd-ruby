module FFWD::Plugin::KairosDB
  module Utils
    # optimized, makes the assumption that all events have the same metadata as
    # the first seen one.
    def self.make_metrics buffer
      groups = {}

      buffer.each do |m|
        entry = {:host => m.host, :name => m.key, :attributes => m.attributes}
        group = (groups[entry] ||= safe_entry(entry).merge(:datapoints => []))
        group[:datapoints] << [(m.time.to_f * 1000).to_i, m.value]
      end

      return groups.values
    end

    # Warning: These are the 'bad' characters I've been able to reverse
    # engineer so far.
    def self.safe_string string
      string = string.to_s
      string = string.gsub " ", "/"
      string.gsub ":", "_"
    end

    # transform the specified entry to a safe entry.
    def self.safe_entry entry
      name = entry[:name]
      host = entry[:host]
      attributes = entry[:attributes]
      {:name => safe_string(name), :tags => make_tags(host, attributes)}
    end

    # Warning: KairosDB ignores complete metrics if you use tags which have no
    # values, therefore I have not figured out a way to transport 'tags'.
    def self.make_tags host, attributes
      tags = {"host" => safe_string(host)}

      attributes.each do |key, value|
        tags[safe_string(key)] = safe_string(value)
      end

      return tags
    end

  end
end
