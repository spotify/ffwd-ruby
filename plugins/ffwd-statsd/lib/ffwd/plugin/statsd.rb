require 'ffwd/plugin'
require 'ffwd/protocol'
require 'ffwd/logging'

require_relative 'statsd/connection'

module FFWD::Plugin::Statsd
  include FFWD::Plugin
  include FFWD::Logging

  register_plugin "statsd"

  DEFAULT_HOST = "localhost"
  DEFAULT_PORT = 8125

  def self.setup_input opts, core
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT
    protocol = FFWD.parse_protocol(opts[:protocol] || "udp")
    protocol.bind opts, core, log, Connection
  end

  def self.setup_tunnel core, tunnel, opts={}
    opts[:port] ||= DEFAULT_PORT
    protocol = FFWD.parse_protocol(opts[:protocol] || "tcp")
    protocol.tunnel opts, core, tunnel, log, Connection
  end
end
