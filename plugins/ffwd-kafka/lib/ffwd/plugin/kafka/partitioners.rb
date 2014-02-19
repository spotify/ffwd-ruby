module FFWD::Plugin::Kafka
  # Use the key for partitioning.
  module KeyPartitioner
    def self.partition d
      d.key
    end
  end

  # Use the host for partitioning.
  module HostPartitioner
    def self.partition d
      d.host
    end
  end

  # Use a custom attribute for partitioning.
  class AttributePartitioner
    DEFAULT_ATTRIBUTE = :site

    def self.build opts
      attr = opts[:attribute] || DEFAULT_ATTRIBUTE
      new attr
    end

    def initialize attr
      @attr = attr.to_sym
      @attr_s = attr.to_s
    end

    # currently there is an issue where you can store both symbols and string
    # as attribute keys, we need to take that into account.
    def partition d
      if v = d.attributes[@attr]
        return v
      end

      d.attributes[@attr_s]
    end
  end

  def self.build_partitioner type, opts
    if type == :host
      return HostPartitioner
    end

    if type == :key
      return KeyPartitioner
    end

    return AttributePartitioner.build opts
  end
end
