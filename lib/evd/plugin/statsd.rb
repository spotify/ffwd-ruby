require 'evd/protocol'
require 'evd/plugin'
require 'evd/logging'

require 'eventmachine'

module EVD::Plugin
  module Statsd
    include EVD::Plugin
    include EVD::Logging

    register_plugin "statsd"

    COUNT = "count"
    GAUGE = "gauge"
    HISTOGRAM = "histogram"

    class Connection < EM::Connection
      include EVD::Logging

      def initialize(buffer)
        @buffer = buffer
      end

      def gauge(name, value)
        {:type => GAUGE, :key => name, :value => value}
      end

      def count(name, value)
        {:type => COUNT, :key => name, :value => value}
      end

      def timing(name, value)
        {:type => HISTOGRAM, :key => name, :value => value}
      end

      def parse(line)
        name, value = line.split ':', 2
        value, type = value.split '|', 2
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
          return timing(name, value, "ms")
        end

        log.warning "Not supported type: #{type}"
        return nil
      end

      def receive_data(data)
        event = parse(data)
        return if event.nil?
        @buffer << event
      rescue => e
        log.error "Failed to receive data", e
      end
    end

    DEFAULT_HOST = "localhost"
    DEFAULT_PORT = 8125

    def self.input_setup(opts={})
      opts[:host] ||= DEFAULT_HOST
      opts[:port] ||= DEFAULT_PORT
      proto = EVD.parse_protocol(opts[:protocol] || "tcp")

      proto.listen log, opts, Connection
    end
  end
end
