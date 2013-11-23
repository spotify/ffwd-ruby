require 'evd/protocol'
require 'evd/plugin'
require 'evd/logging'

require 'eventmachine'

require 'beefcake'

require 'riemann/query'
require 'riemann/attribute'
require 'riemann/state'
require 'riemann/event'
require 'riemann/message'

module EVD
  module Riemann
    include EVD::Plugin
    include EVD::Logging

    register_plugin "riemann"

    class RiemannTCPConnection < EventMachine::Connection
      include EVD::Logging

      def initialize(output, host, port)
        @host = host
        @port = port
        @bad_acks = 0
        @output = output
      end

      def connection_completed
        log.info "Connected to #{@host}:#{@port}"
        @output.connected = self
      end

      def unbind
        log.info "Disconnected from #{@host}:#{@port}"
        @output.connected = nil
        @output.reconnect
      end

      def receive_data(data)
        message = ::Riemann::Message.decode data

        # Not a lot to do to handle the situation.
        if not message.ok
          @bad_acks += 1
          log.warning "#{@ip}:#{@port}: Received bad acknowledge"
        end
      end
    end

    module RiemannOutputBase
      def make_event(event)
        ::Riemann::Event.new(
          :service => event[:key],
          :metric => event[:value],
          :tags => @tags,
          :attributes => @attributes
        )
      end

      def make_message(message)
        ::Riemann::Message.new(
          :events => message[:events]
        )
      end

      def collect_events(buffer)
        buffer.pop do |event|
          handle_input event
          collect_events buffer
        end
      end

      def handle_input(event)
        if @connected.nil?
          @dropped_messages += 1
          return
        end

        handle event
      end
    end

    class RiemannTCPOutput
      include EVD::Logging
      include RiemannOutputBase

      def initialize(host, port, tags, attributes)
        @host = host
        @port = port
        @tags = tags
        @attributes = attributes
        @connected = nil
        @dropped_messages = 0

        @reconnect_timeout = 2
      end

      def handle(event)
        e = make_event(event)
        m = make_message :events => [e]
        @connected.send_data m.encode_with_length
      end

      def setup(buffer)
        connect
        collect_events buffer
      end

      def connected=(value)
        @connected = value
        # reset timeout if this is a new connection.
        @reconnect_timeout = 2 unless value.nil?
      end

      def connect
        return unless @connected.nil?
        EventMachine.connect(@host, @port, RiemannTCPConnection,
                             self, @host, @port)
      end

      def reconnect
        log.info "Reconnecting in #{@reconnect_timeout}s"
        EventMachine::Timer.new(@reconnect_timeout) do
          @reconnect_timeout *= 2
          connect
        end
      end
    end

    class RiemannUDPOutput
      include EVD::Logging
      include RiemannOutputBase

      def initialize(host, port, tags, attributes)
        @host = host
        @port = port
        @tags = tags
        @attributes = attributes
        @connected = nil
        @dropped_messages = 0

        @bind_host = "0.0.0.0"
        @host_ip = nil
      end

      def handle(event)
        e = make_event(event)
        m = make_message :events => [e]
        @connected.send_datagram m.encode, @host_ip, @port
      end

      def setup(buffer)
        @host_ip = resolve_host_ip @host

        if @host_ip.nil?
          log.error "Could not resolve '#{@host}'"
          return
        end

        log.info "Resolved server as #{@host_ip}"

        EventMachine.open_datagram_socket(@bind_host, nil) do |connected|
          @connected = connected
          collect_events buffer
        end
      end

      private

      def resolve_host_ip(host)
        Socket.getaddrinfo(@host, nil, nil, :DGRAM).each do |item|
          next if item[0] != "AF_INET"
          return item[3]
        end

        return nil
      end
    end

    DEFAULT_PORT = {
      "tcp" => 5555,
      "udp" => 5555,
    }

    def self.output_setup(opts={})
      host = opts[:host] || "localhost"
      protocol = EVD.parse_protocol(opts[:protocol] || "tcp")
      port = opts[:port] || DEFAULT_PORT[protocol.name]
      tags = opts[:tags] || []
      attributes = opts[:attributes] || {}

      if protocol == TCPProtocol
        return RiemannTCPOutput.new host, port, tags, attributes
      end

      return RiemannUDPOutput.new host, port, tags, attributes
    end
  end
end
