require 'eventmachine'
require 'beefcake'

require 'riemann/query'
require 'riemann/attribute'
require 'riemann/state'
require 'riemann/event'
require 'riemann/message'

require_relative '../protocol'
require_relative '../plugin'
require_relative '../logging'

require_relative 'riemann/utils'
require_relative 'riemann/handler'

module EVD::Plugin::Riemann
  include EVD::Plugin
  include EVD::Logging

  register_plugin "riemann"

  class HandlerTCP
    include EVD::Plugin::Riemann::Utils
    include EVD::Plugin::Riemann::Handler

    def initialize
      setup_handler
    end

    def encode(m)
      m.encode_with_length
    end
  end

  class HandlerUDP
    include EVD::Plugin::Riemann::Utils
    include EVD::Plugin::Riemann::Handler

    def initialize
      setup_handler
    end

    def encode(m)
      m.encode
    end
  end

  class ConnectionBase < EM::Connection
    include EVD::Plugin::Riemann::Utils

    module RiemannSerializer
      def self.dump(m)
        m.encode.to_s
      end

      def self.load(data)
        ::Riemann::Message.decode(data)
      end
    end

    def initialize input, output, log
      @input = input
      @log = log
    end

    def serializer
      RiemannSerializer
    end

    def receive_object(m)
      unless m.events.nil? or m.events.empty?
        m.events.each do |e|
          @input.event read_event(e)
        end
      end

      send_ok
    rescue => e
      @log.error "Failed to receive object", e
      send_error e
    end

    protected

    def send_ok; end
    def send_error(e); end
  end

  class ConnectionTCP < ConnectionBase
    include EM::Protocols::ObjectProtocol

    def send_ok
      send_object(::Riemann::Message.new(
        :ok => true))
    end

    def send_error(e)
      send_object(::Riemann::Message.new(
        :ok => false, :error => e.to_s))
    end
  end

  class ConnectionUDP < ConnectionBase
    def receive_data(data)
      receive_object serializer.load(data)
    end
  end

  DEFAULT_HOST = "localhost"
  DEFAULT_PORT = 5555
  DEFAULT_PROTOCOL = 'tcp'

  HANDLERS = {:tcp => HandlerTCP, :udp => HandlerUDP}
  CONNECTIONS = {:tcp => ConnectionTCP, :udp => ConnectionUDP}

  def self.connect core, opts={}
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT

    protocol = EVD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)

    unless handler = HANDLERS[protocol.family]
      raise "No handler for protocol family: #{protocol.family}"
    end

    instance = handler.new

    protocol.connect log, opts, instance
  end

  def self.bind core, opts={}
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT
    protocol = EVD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)

    unless connection = CONNECTIONS[protocol.family]
      raise "No connection for protocol family: #{protocol.family}"
    end

    protocol.bind log, opts, connection, log
  end

  def self.tunnel core, opts={}
    opts[:port] ||= DEFAULT_PORT
    protocol = EVD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)

    unless connection = CONNECTIONS[protocol.family]
      raise "No connection for protocol family: #{protocol.family}"
    end

    protocol.tunnel log, opts, connection, log
  end
end
