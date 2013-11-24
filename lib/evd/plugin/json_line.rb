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

    class Connection < EventMachine::Connection
      include EVD::Logging
      include EventMachine::Protocols::LineText2

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

        type = data["$type"]
        key = data["key"]
        value = data["value"]

        return if type.nil?
        return if key.nil?
        return if value.nil?

        @input_buffer << {:type => type, :key => key, :value => value}
      rescue
        puts "Something went wrong: #{$!}"
      end
    end

    class TCP
      include EVD::Logging

      def initialize(host, port, buffer_limit)
        @host = host
        @port = port
        @peer = "#{@host}:#{@port}"
        @buffer_limit = buffer_limit
      end

      def start(buffer)
        EventMachine.start_server(@host, @port, Connection,
                                  buffer, @buffer_limit)
        log.info "Listening on #{@peer}"
      end
    end

    class UDP
      include EVD::Logging

      def initialize(host, port, buffer_limit)
        @host = host
        @port = port
        @peer = "#{@host}:#{@port}"
        @buffer_limit = buffer_limit
      end

      def start(buffer)
        @peer = "#{@host}:#{@port}"
        EventMachine.open_datagram_socket(
          @host, @port, JsonLineConnection, buffer, @buffer_limit)
        log.info "Listening on #{@peer}"
      end
    end

    def self.input_setup(opts={})
      host = opts[:host] || "localhost"
      port = opts[:port] || 3000
      buffer_limit = opts["buffer_limit"] || 1000
      proto = EVD.parse_protocol(opts[:protocol] || "tcp")

      return TCP.new host, port, buffer_limit if proto == :tcp
      return UDP.new host, port, buffer_limit if proto == :udp

      throw Exception.new("Unsupported protocol '#{proto}'")
    end
  end
end
