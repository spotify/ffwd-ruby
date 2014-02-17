require 'eventmachine'

require 'ffwd/logging'
require 'ffwd/connection'

module FFWD::Plugin
  module Carbon
    class Connection < FFWD::Connection
      include FFWD::Logging
      include EM::Protocols::LineText2

      def self.plugin_type
        "carbon_in"
      end

      def initialize bind, core
        @bind = bind
        @core = core
      end

      def parse(line)
        path, value, timestamp = line.split ' ', 3
        raise "invalid frame" if timestamp.nil?

        return nil if path.empty? or value.empty? or timestamp.empty?

        value = value.to_f unless value.nil?
        time = Time.at(timestamp.to_i)

        return {:key => path, :value => value, :time => time}
      end

      def receive_line(ln)
        metric = parse(ln)
        return if metric.nil?
        @core.input.metric metric
        @bind.increment :received_metrics
      rescue => e
        log.error "Failed to receive data", e
      end
    end
  end
end
