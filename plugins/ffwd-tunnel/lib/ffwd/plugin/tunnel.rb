require 'eventmachine'
require 'base64'

require_relative 'tunnel/connection_tcp'
require_relative 'tunnel/text_protocol'
require_relative 'tunnel/binary_protocol'

require 'ffwd/logging'
require 'ffwd/plugin'
require 'ffwd/protocol'

module FFWD::Plugin::Tunnel
  include FFWD::Plugin
  include FFWD::Logging

  register_plugin "tunnel"

  DEFAULT_HOST = 'localhost'
  DEFAULT_PORT = 9000
  DEFAULT_PROTOCOL = 'tcp'
  DEFAULT_PROTOCOL_TYPE = 'text'

  CONNECTIONS = {:tcp => ConnectionTCP}

  PROTOCOL_TYPES = {
    "text" => TextProtocol,
    "binary" => BinaryProtocol,
  }

  def self.setup_input opts, core
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT
    protocol = FFWD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)
    protocol_type = opts[:protocol_type] || DEFAULT_PROTOCOL_TYPE

    unless connection = CONNECTIONS[protocol.family]
      raise "No connection for protocol family: #{protocol.family}"
    end

    unless protocol_type = PROTOCOL_TYPES[protocol_type]
      raise "No such tunnel protocol: #{protocol_type}"
    end

    if core.tunnel_plugins.empty?
      raise "Nothing requires tunneling"
    end

    protocol.bind opts, core, log, connection, protocol_type
  end
end
