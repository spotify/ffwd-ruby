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
    TIMING = "timing"

    class StatsdConnection < EventMachine::Connection
      include EVD::Logging

      def initialize(input_buffer, buffer_limit)
        @input_buffer = input_buffer
        @buffer_limit = buffer_limit
      end

      def gauge(name, value)
        {:type => GAUGE, :key => name, :value => value}
      end

      def count(name, value)
        {:type => COUNT, :key => name, :value => value}
      end

      def timing(name, value, unit)
        {:type => TIMING, :unit => unit, :key => name, :value => value}
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
        if @input_buffer.size > @buffer_limit
          log.warning "Buffer limit reached, dropping event"
          return
        end

        event = parse(data)

        return if event.nil?

        @input_buffer << event
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

      def setup(buffer)
        EventMachine.start_server(
          @host, @port, StatsdConnection, buffer, @buffer_limit)
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

      def setup(buffer)
        EventMachine.open_datagram_socket(
          @host, @port, StatsdConnection, buffer, @buffer_limit)
        log.info "Listening on #{@peer}"
      end
    end

    def self.input_setup(opts={})
      host = opts[:host] || "localhost"
      port = opts[:port] || 8125
      buffer_limit = opts["buffer_limit"] || 1000
      proto = EVD.parse_protocol(opts[:protocol] || "tcp")

      return UDP.new host, port, buffer_limit if proto == :udp
      return TCP.new host, port, buffer_limit if proto == :tcp

      throw Exception.new("Unsupported protocol '#{proto}'")
    end
  end
end
