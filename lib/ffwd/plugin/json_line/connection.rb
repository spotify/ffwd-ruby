require 'eventmachine'

require 'ffwd/logging'
require 'ffwd/connection'

module FFWD::Plugin::JsonLine
  class Connection < FFWD::Connection
    include FFWD::Logging
    include EM::Protocols::LineText2

    EVENT_FIELDS = [
      ["key", :key],
      ["value", :value],
      ["host", :host],
      ["state", :state],
      ["description", :description],
      ["ttl", :ttl],
      ["tags", :tags],
      ["attributes", :attributes],
    ]

    METRIC_FIELDS = [
      ["proc", :proc],
      ["key", :key],
      ["value", :value],
      ["tags", :tags],
      ["attributes", :attributes]
    ]

    def self.plugin_type
      "json_line_in"
    end

    def initialize bind, core, buffer_limit
      @bind = bind
      @core = core
      @buffer_limit = buffer_limit
    end

    def receive_line data
      data = JSON.load(data)

      unless type = data["type"]
        log.error "Field 'type' missing from received line"
        return
      end

      if type == "metric"
        @core.input.metric read_metric(data)
        @bind.increment :received_metric
        return
      end

      if type == "event"
        @core.input.event read_event(data)
        @bind.increment :received_event
        return
      end

      log.error "No such type: #{type}"
    rescue => e
      log.error "Failed to receive line", e
    end

    def read_tags d, source
      return if (tags = d["tags"]).nil?
      d[:tags] = tags.to_set
    end

    def read_time d, source
      return if (time = d["time"]).nil?
      d[:time] = Time.at time
    end

    def read_metric data
      d = {}

      read_tags d, data["tags"]
      read_time d, data["time"]

      METRIC_FIELDS.each do |from, to|
        next if (v = data[from]).nil?
        d[to] = v
      end

      d
    end

    def read_event data
      d = {}

      read_tags d, data["tags"]
      read_time d, data["time"]

      EVENT_FIELDS.each do |from, to|
        next if (v = data[from]).nil?
        d[to] = v
      end

      d
    end
  end
end
