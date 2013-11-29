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

    class BaseOut
      attr_reader :dropped_messages

      def initialize(tags, attributes)
        @tags = Set.new(tags || [])
        @attributes = attributes || {}
        @dropped_messages = 0
      end

      def make_event(s)
        tags = @tags
        tags += s[:tags] unless s[:tags].nil?
        tags = tags.map{|v| v.dup}

        attributes = @attributes
        attributes = attributes.merge(s[:attributes]) unless s[:attributes].nil?
        attributes = attributes.map{|k, v|
          ::Riemann::Attribute.new(:key => k.dup, :value => v.dup)
        }

        e = ::Riemann::Event.new

        e.service = s[:key] unless s[:key].nil?
        e.metric = s[:value] unless s[:value].nil?
        e.host = s[:host] unless s[:host].nil?
        e.state = s[:state] unless s[:state].nil?
        e.description = s[:description] unless s[:description].nil?
        e.ttl = s[:ttl] unless s[:ttl].nil?
        e.time = s[:time] unless s[:time].nil?
        e.tags = tags unless tags.empty?
        e.attributes = attributes unless attributes.empty?

        e
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

    class OutputTCP < BaseOut
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
        rescue => e
          log.error "Failed to send events: #{e}"
          log.error e.backtrace.join("\n")
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

    class OutputUDP < BaseOut
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

    module RiemannSerializer
      def self.dump(m)
        m.encode.to_s
      end

      def self.load(data)
        ::Riemann::Message.decode(data)
      end
    end

    class InputTCP
      include EVD::Logging

      class Connection < EventMachine::Connection
        include EVD::Logging
        include EventMachine::Protocols::ObjectProtocol

        def initialize(buffer)
          @buffer = buffer
        end

        def serializer
          RiemannSerializer
        end

        def receive_object(m)
          m.events.each do |e|
            o = {:type => 'event'}

            unless e.attributes.nil?
              attributes = {}

              e.attributes.each do |a|
                attributes[a.key] = a.value
              end
            else
              attributes = nil
            end

            o[:key] = e.service unless e.service.nil?
            o[:value] = e.metric unless e.metric.nil?
            o[:host] = e.host unless e.host.nil?
            o[:state] = e.state unless e.state.nil?
            o[:description] = e.description unless e.description.nil?
            o[:ttl] = e.ttl unless e.ttl.nil?
            o[:time] = e.time unless e.time.nil?
            o[:tags] = e.tags unless e.tags.nil? or e.tags.empty?
            o[:attributes] = attributes unless attributes.nil?

            @buffer << o
          end

          send_object(::Riemann::Message.new(:ok => true))
        rescue => e
          log.error "Failed to receive object: #{e}"
          log.error e.backtrace.join("\n")

          send_object(::Riemann::Message.new(:ok => false, :error => e.to_s))
        end
      end

      def initialize(host, port)
        @host = host
        @port = port
        @peer = "#{host}:#{port}"
      end

      def start(buffer)
        log.info "Listening on #{@peer}"
        EventMachine.start_server(@host, @port, Connection, buffer)
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
        return OutputTCP.new host, port, tags, attributes, flush_period
      end

      return OutputUDP.new host, port, tags, attributes
    end

    def self.input_setup(opts={})
      host = opts[:host] || "localhost"
      protocol = EVD.parse_protocol(opts[:protocol] || "tcp")
      port = opts[:port] || DEFAULT_PORT[protocol]

      if protocol == :tcp
        return InputTCP.new host, port
      end

      raise "Not supported"
    end
  end
end
