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

  class OutputTCP
    include EVD::Plugin::Riemann::Shared
    include EVD::Plugin::Riemann::Handler

    def initialize
      setup_handler
    end

    def encode(m)
      m.encode_with_length
    end
  end

  class OutputUDP
    include EVD::Plugin::Riemann::Shared
    include EVD::Plugin::Riemann::Handler

    def initialize
      setup_handler
    end

    def encode(m)
      m.encode
    end
  end

  class InputTCP < EVD::Connection
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

  class InputUDP < EVD::Connection
    include EVD::Plugin::Riemann::Shared
    include EVD::Plugin::Riemann::Connection

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

    protocol = EVD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)

    unless handler = OUTPUTS[protocol.family]
      raise "No handler for protocol family: #{protocol.family}"
    end

    instance = handler.new

    protocol.connect log, opts, instance
  end

  def self.setup_input core, opts={}
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT
    protocol = EVD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)

    unless connection = INPUTS[protocol.family]
      raise "No connection for protocol family: #{protocol.family}"
    end

    protocol.bind log, opts, connection, log
  end

  def self.setup_tunnel core, opts={}
    opts[:port] ||= DEFAULT_PORT
    protocol = EVD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)

    unless connection = INPUTS[protocol.family]
      raise "No connection for protocol family: #{protocol.family}"
    end

    protocol.tunnel log, opts, connection, log
  end
end
