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

    MAPPING = [
      [:key, :service, :service=],
      [:value, :metric, :metric=],
      [:host, :host, :host=],
      [:state, :state, :state=],
      [:description, :description, :description=],
      [:ttl, :ttl, :ttl=],
      [:time, :time, :time=],
    ]

    register_plugin "riemann"

    class Handler
      include EVD::Logging

      def initialize(tags, attributes)
        @tags = Set.new(tags || [])
        @attributes = attributes || {}
        @bad_acks = 0
      end

      def serialize_events(events)
        events = events.map{|e| make_event(e)}
        message = make_message :events => events
        message.encode_with_length
      end

      def serialize_event(event)
        e = make_event(event)
        m = make_message :events => [e]
        m.encode
      end

      def recv_data(peer, data)
        message = read_message data

        return if message.ok

        @bad_acks += 1
        log.warning "(#{peer}) Bad riemann acknowledge received"
      end

      private

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

        e.tags = tags unless tags.empty?
        e.attributes = attributes unless attributes.empty?

        MAPPING.each do |key, reader, writer|
          next if (v = s[key]).nil?
          e.send(writer, v)
        end

        e
      end

      def make_message(message)
        ::Riemann::Message.new(:events => message[:events])
      end

      def read_message(data)
        ::Riemann::Message.decode data
      end
    end

    class Connection < EventMachine::Connection
      include EVD::Logging
      include EventMachine::Protocols::ObjectProtocol

      module RiemannSerializer
        def self.dump(m)
          m.encode.to_s
        end

        def self.load(data)
          ::Riemann::Message.decode(data)
        end
      end

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

            e.attributes.each do |attr|
              attributes[attr.key] = attr.value
            end

            o[:attributes] = attributes unless attributes.empty?
          end

          unless e.tags.nil? or e.tags.empty?
            o[:tags] = e.tags
          end

          MAPPING.each do |key, reader, writer|
            next if (v = e.send(reader)).nil?
            o[key] = v
          end

          @buffer << o
        end

        send_object(::Riemann::Message.new(:ok => true))
      rescue => e
        log.error "Failed to receive object: #{e}"
        log.error e.backtrace.join("\n")

        send_object(::Riemann::Message.new(:ok => false, :error => e.to_s))
      end
    end

    DEFAULT_HOST = "localhost"
    DEFAULT_PORT = 5555

    def self.output_setup(opts={})
      opts[:host] ||= DEFAULT_HOST
      opts[:port] ||= DEFAULT_PORT

      attributes = opts[:attributes] || {}
      tags = opts[:tags] || []
      handler = Handler.new tags, attributes

      protocol = EVD.parse_protocol(opts[:protocol] || "tcp")
      protocol.connect log, opts, handler
    end

    def self.input_setup(opts={})
      opts[:host] ||= DEFAULT_HOST
      opts[:port] ||= DEFAULT_PORT
      protocol = EVD.parse_protocol(opts[:protocol] || "tcp")
      protocol.listen log, opts, Connection
    end
  end
end
