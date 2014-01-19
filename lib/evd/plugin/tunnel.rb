require 'eventmachine'
require 'base64'

require_relative 'tunnel/connection_tcp'
require_relative 'tunnel/text_protocol'
require_relative 'tunnel/binary_protocol'

require_relative '../logging'
require_relative '../plugin'
require_relative '../protocol'

module EVD::Plugin::Tunnel
  include EVD::Plugin
  include EVD::Logging

  register_plugin "tunnel"

  DEFAULT_HOST = "localhost"
  DEFAULT_PORT = 9000
  DEFAULT_PROTOCOL = 'tcp'
  DEFAULT_TYPE = :text

  CONNECTIONS = {:tcp => ConnectionTCP}
  
  PROTOCOLS = {
    "text" => TextProtocol,
    "binary" => BinaryProtocol,
  }

  def self.setup_input core, opts={}
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT
    protocol = EVD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)
    protocol_type = opts[:protocol_type] || DEFAULT_TYPE

    unless connection = CONNECTIONS[protocol.family]
      raise "No connection for protocol family: #{protocol.family}"
    end

    unless tunnel_protocol = PROTOCOLS[protocol_type]
      raise "No such tunnel protocol: #{protocol_type}"
    end

    if core.tunnels.empty?
      raise "Nothing requires tunneling"
    end

    protocol.bind log, opts, connection, core, tunnel_protocol
  end
end
