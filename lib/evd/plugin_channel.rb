module EVD
  class PluginChannel
    attr_reader :metrics
    attr_reader :events

    def initialize metrics, events
      @metrics = metrics
      @events = events
    end
  end
end
