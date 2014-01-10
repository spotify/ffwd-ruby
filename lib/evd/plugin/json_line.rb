require 'evd/protocol'
require 'evd/plugin'
require 'evd/logging'

require 'eventmachine'
require 'set'

module EVD::Plugin
  module JsonLine
    include EVD::Plugin
    include EVD::Logging

    register_plugin "json_line"

    class Connection < EM::Connection
      include EVD::Logging
      include EM::Protocols::LineText2

      EVENT_FIELDS = [
        ["key", :key],
        ["value", :value],
        ["host", :host],
        ["state", :state],
        ["description", :description],
        ["ttl", :ttl],
        ["time", :time],
        ["tags", :tags],
        ["attributes", :attributes],
      ]

      METRIC_FIELDS = [
        ["processor", :processor],
        ["key", :key],
        ["value", :value],
        ["time", :time],
        ["tags", :tags],
        ["attributes", :attributes]
      ]

      def initialize(channel, buffer_limit)
        @events = channel.events
        @metrics = channel.metrics
        @buffer_limit = buffer_limit
      end

      def receive_line(data)
        data = JSON.load(data)

        unless type = data["type"]
          log.error "Type missing from data"
          return
        end

        receive_metric data if type == "metric"
        receive_event data if type == "event"

        log.error "No such type: #{type}"
      rescue => e
        log.error "Failed to receive line", e
      end
    end

    def receive_metric data
      d = Hash[METRIC_FIELDS.each do |from, to|
        next if (v = data[from]).nil?
        d[to] = v
      end]

      unless tags = d[:tags]
        d[:tags] = tags.to_set
      end

      @metrics << d
    end

    def receive_event data
      d = Hash[EVENT_FIELDS.each do |from, to|
        next if (v = data[from]).nil?
        d[to] = v
      end]

      unless tags = d[:tags]
        d[:tags] = tags.to_set
      end

      @events << d
    end

    DEFAULT_HOST = "localhost"
    DEFAULT_PORT = 3000

    def self.input_setup(opts={})
      opts[:host] ||= DEFAULT_HOST
      opts[:port] ||= DEFAULT_PORT
      buffer_limit = opts["buffer_limit"] || 1000
      protocol = EVD.parse_protocol(opts[:protocol] || "tcp")
      protocol.listen log, opts, Connection, buffer_limit
    end
  end
end
