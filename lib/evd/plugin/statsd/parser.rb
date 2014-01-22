module EVD::Plugin::Statsd
  module Parser
    COUNT = "count"
    HISTOGRAM = "histogram"

    def self.gauge name, value
      {:proc => nil, :key => name, :value => value}
    end

    def self.count name, value
      {:proc => COUNT, :key => name, :value => value}
    end

    def self.timing name, value
      {:proc => HISTOGRAM, :key => name, :value => value}
    end

    def self.parse line
      name, value = line.split ':', 2
      raise "invalid frame" if value.nil?
      value, type = value.split '|', 2
      raise "invalid frame" if type.nil?
      type, sample_rate = type.split '|@', 2

      return nil if type.nil? or type.empty?
      return nil if value.nil? or value.empty?

      value = value.to_f unless value.nil?
      sample_rate = sample_rate.to_f unless sample_rate.nil?

      value /= sample_rate unless sample_rate.nil?

      if type == "g"
        return gauge(name, value)
      end

      if type == "c"
        return count(name, value)
      end

      if type == "ms"
        return timing(name, value)
      end

      log.warning "Not supported type: #{type}"
      return nil
    end
  end
end
