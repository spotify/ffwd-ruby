require 'evd/plugin'
require 'evd/protocol'
require 'evd/logging'

require_relative 'statsd/connection'

module EVD::Plugin::Statsd
  include EVD::Plugin
  include EVD::Logging

  register_plugin "statsd"

  DEFAULT_HOST = "localhost"
  DEFAULT_PORT = 8125

  def self.setup_input core, opts={}
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT
    protocol = EVD.parse_protocol(opts[:protocol] || "tcp")
    protocol.bind log, opts, Connection
  end

  def self.setup_tunnel core, opts={}
    opts[:port] ||= DEFAULT_PORT
    protocol = EVD.parse_protocol(opts[:protocol] || "tcp")
    protocol.tunnel log, opts, Connection
  end
end
