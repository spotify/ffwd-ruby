require 'eventmachine'

require 'ffwd/protocol'
require 'ffwd/plugin'
require 'ffwd/logging'
require 'ffwd/connection'

module FFWD::Plugin
  module Carbon
    include FFWD::Plugin
    include FFWD::Logging

    register_plugin "carbon"

    class Connection < FFWD::Connection
      include FFWD::Logging
      include EM::Protocols::LineText2

      def self.name
        "carbon"
      end

      def initialize core
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
      rescue => e
        log.error "Failed to receive data", e
      end
    end

    DEFAULT_HOST = "localhost"
    DEFAULT_PORT = 2003
    DEFAULT_PROTOCOL = "tcp"

    def self.setup_input opts, core
      opts[:host] ||= DEFAULT_HOST
      opts[:port] ||= DEFAULT_PORT
      protocol = FFWD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)
      protocol.bind opts, core, log, Connection
    end

    def self.setup_tunnel opts, core, tunnel
      opts[:port] ||= DEFAULT_PORT
      protocol = FFWD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)
      protocol.tunnel opts, core, tunnel, log, Connection
    end
  end
end
