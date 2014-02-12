require 'eventmachine'
require 'beefcake'

require 'riemann/query'
require 'riemann/attribute'
require 'riemann/state'
require 'riemann/event'
require 'riemann/message'

require 'ffwd/connection'
require 'ffwd/handler'
require 'ffwd/logging'
require 'ffwd/plugin'
require 'ffwd/protocol'

require_relative 'riemann/connection'
require_relative 'riemann/shared'
require_relative 'riemann/handler'

module FFWD::Plugin::Riemann
  include FFWD::Plugin
  include FFWD::Logging

  register_plugin "riemann"

  class OutputTCP < FFWD::Handler
    include FFWD::Plugin::Riemann::Shared
    include FFWD::Plugin::Riemann::Handler

    def self.name
      "riemann_tcp_out"
    end

    def encode m
      m.encode_with_length
    end
  end

  class OutputUDP < FFWD::Handler
    include FFWD::Plugin::Riemann::Shared
    include FFWD::Plugin::Riemann::Handler

    def self.name
      "riemann_udp_out"
    end

    def encode m
      m.encode
    end
  end

  class InputTCP < FFWD::Connection
    include EM::Protocols::ObjectProtocol
    include FFWD::Plugin::Riemann::Shared
    include FFWD::Plugin::Riemann::Connection

    def self.name
      "riemann_tcp_in"
    end

    def send_ok
      send_object(::Riemann::Message.new(
        :ok => true))
    end

    def send_error(e)
      send_object(::Riemann::Message.new(
        :ok => false, :error => e.to_s))
    end
  end

  class InputUDP < FFWD::Connection
    include FFWD::Plugin::Riemann::Shared
    include FFWD::Plugin::Riemann::Connection

    def self.name
      "riemann_udp_in"
    end

    def receive_data(data)
      receive_object serializer.load(data)
    end
  end

  DEFAULT_HOST = "localhost"
  DEFAULT_PORT = 5555
  DEFAULT_PROTOCOL = 'tcp'

  OUTPUTS = {:tcp => OutputTCP, :udp => OutputUDP}
  INPUTS = {:tcp => InputTCP, :udp => InputUDP}

  def self.setup_output core, opts={}
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT

    protocol = FFWD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)

    unless type = OUTPUTS[protocol.family]
      raise "No type for protocol family: #{protocol.family}"
    end

    protocol.connect core, log, opts, type
  end

  def self.setup_input opts, core
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT
    protocol = FFWD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)

    unless connection = INPUTS[protocol.family]
      raise "No connection for protocol family: #{protocol.family}"
    end

    protocol.bind opts, core, log, connection, log
  end

  def self.setup_tunnel opts, core, tunnel
    opts[:port] ||= DEFAULT_PORT
    protocol = FFWD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)

    unless connection = INPUTS[protocol.family]
      raise "No connection for protocol family: #{protocol.family}"
    end

    protocol.tunnel opts, core, tunnel, log, connection, log
  end
end
