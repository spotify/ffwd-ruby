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

module EVD::Plugin
  module Riemann
    include EVD::Plugin
    include EVD::Logging

    register_plugin "riemann"

    class Base
      attr_reader :dropped_messages

      def initialize(tags, attributes)
        @tags = tags
        @attributes = attributes
        @dropped_messages = 0
      end

      def make_event(event)
        ::Riemann::Event.new(
          :service => event[:key],
          :metric => event[:value],
          :description => event[:message],
          :tags => @tags,
          :attributes => @attributes
        )
      end

      def make_message(message)
        ::Riemann::Message.new(
          :events => message[:events]
        )
      end

      protected

      def handle_event(event); raise "Not implemented: handle_event"; end

      def collect_events(buffer)
        buffer.pop do |event|
          handle_event event
          collect_events buffer
        end
      end
    end

    class TCP < Base
      include EVD::Logging

      class Connection < EventMachine::Connection
        include EVD::Logging

        INITIAL_TIMEOUT = 2

        def initialize(host, port)
          @bad_acks = 0
          @host = host
          @port = port

          @peer = "#{host}:#{port}"
          @timeout = INITIAL_TIMEOUT

          @connected = false
          @timer = nil
        end

        def connected?
          @connected
        end

        def connection_completed
          @connected = true

          log.info "(#{@peer}) Connected"

          unless @timer.nil?
            @timer.cancel
            @timer = nil
          end

          @timeout = INITIAL_TIMEOUT
        end

        def unbind
          @connected = false

          log.info "(#{@peer}) Disconnected, reconnect in #{@timeout}s"

          @timer = EventMachine::Timer.new(@timeout) do
            @timeout *= 2
            @timer = nil
            reconnect @host, @port
          end
        end

        def receive_data(data)
          message = read_message data

          # Not a lot to do to handle the situation.
          unless message.ok
            @bad_acks += 1
            log.warning "(#{@peer}) Bad riemann ACK"
          end
        end

        private

        def read_message(data)
          ::Riemann::Message.decode data
        end
      end

      def initialize(host, port, tags, attributes, flush_period)
        super tags, attributes

        @host = host
        @port = port
        @flush_period = flush_period

        @conn = nil
        @buffer = []
      end

      def handle_event(event)
        @buffer << event
      end

      #
      # Flush buffered events (if any).
      #
      def flush_events
        return if @buffer.empty?
        return unless @conn.connected?

        events = @buffer.map{|e| make_event(e)}
        message = make_message :events => events

        @buffer = []

        begin
          data = message.encode_with_length
          @conn.send_data data
        rescue
          log.error "Failed to send events: #{$!}"
        end
      end

      #
      # start riemann tcp connection.
      #
      def start(buffer)
        EventMachine.connect(@host, @port, Connection, @host, @port) do |conn|
          @conn = conn
        end

        EventMachine::PeriodicTimer.new(@flush_period) do
          flush_events
        end

        collect_events buffer
      end
    end

    class UDP < Base
      include EVD::Logging

      def initialize(host, port, tags, attributes)
        super tags, attributes

        @host = host
        @port = port

        @bind_host = "0.0.0.0"
        @host_ip = nil
        @conn = nil
      end

      def handle_event(event)
        e = make_event(event)
        m = make_message :events => [e]
        @conn.send_datagram m.encode, @host_ip, @port
      end

      def start(buffer)
        @host_ip = resolve_host_ip @host

        if @host_ip.nil?
          log.error "Could not resolve '#{@host}'"
          return
        end

        log.info "Resolved server as #{@host_ip}"

        EventMachine.open_datagram_socket(@bind_host, nil) do |conn|
          @conn = conn
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
      :tcp => 5555,
      :udp => 5555,
    }

    def self.output_setup(opts={})
      host = opts[:host] || "localhost"
      protocol = EVD.parse_protocol(opts[:protocol] || "tcp")
      port = opts[:port] || DEFAULT_PORT[protocol]
      tags = opts[:tags] || []
      attributes = opts[:attributes] || {}

      if protocol == :tcp
        flush_period = opts[:flush_period] || 10
        return TCP.new host, port, tags, attributes, flush_period
      end

      return UDP.new host, port, tags, attributes
    end
  end
end
