module EVD::Statistics
  class ChannelStatistics
    def initialize channels, opts={}
      @channels = channels
      @precision = opts[:precision] || 3
    end

    def collect now, last
      diff = now - last

      @channels.each do |channel|
        stats = channel.stats!

        stats.each do |k, v|
          value = (v.to_f / diff).round(@precision)
          key = "#{self.class.name}(#{channel.name}) #{k} rate"
          yield key, value
        end
      end
    end
  end
end
