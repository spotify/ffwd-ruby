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
require_relative '../connection'

require_relative 'riemann/connection'
require_relative 'riemann/shared'
require_relative 'riemann/handler'

module EVD::Plugin::Riemann
  include EVD::Plugin
  include EVD::Logging

  register_plugin "riemann"

  class HandlerTCP
    include EVD::Plugin::Riemann::Shared
    include EVD::Plugin::Riemann::Handler

    def initialize
      setup_handler
    end

    def encode(m)
      m.encode_with_length
    end
  end

  class HandlerUDP
    include EVD::Plugin::Riemann::Shared
    include EVD::Plugin::Riemann::Handler

    def initialize
      setup_handler
    end

    def encode(m)
      m.encode
    end
  end

  class ConnectionTCP < EVD::Connection
    include EM::Protocols::ObjectProtocol
    include EVD::Plugin::Riemann::Shared
    include EVD::Plugin::Riemann::Connection

    def send_ok
      send_object(::Riemann::Message.new(
        :ok => true))
    end

    def send_error(e)
      send_object(::Riemann::Message.new(
        :ok => false, :error => e.to_s))
    end
  end

  class ConnectionUDP < EVD::Connection
    include EVD::Plugin::Riemann::Shared
    include EVD::Plugin::Riemann::Connection

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
