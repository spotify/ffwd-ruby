require 'evd/protocol'
require 'evd/plugin'
require 'evd/logging'
require 'evd/data_type'

require 'eventmachine'

module EVD::Plugin
  module JsonLine
    include EVD::Plugin
    include EVD::Logging

    register_plugin "json_line"

    class Connection < EM::Connection
      include EVD::Logging
      include EM::Protocols::LineText2

      FIELDS = [
        ["type", :type],
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

      def initialize(input_buffer, buffer_limit)
        @input_buffer = input_buffer
        @buffer_limit = buffer_limit
      end

      def receive_line(data)
        if @input_buffer.size > @buffer_limit
          log.warning "Buffer limit reached, dropping event"
          return
        end

        data = JSON.load(data)

        d = Hash.new

        FIELDS.each do |from, to|
          next if (v = data[from]).nil?
          d[to] = v
        end

        @input_buffer << d
      rescue => e
        log.error "Something went wrong: #{e}"
        log.error e.backtrace.join("\n")
      end
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
