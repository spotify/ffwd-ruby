require 'ffwd/protocol'
require 'ffwd/plugin'
require 'ffwd/logging'

require_relative 'carbon/connection'

module FFWD::Plugin
  module Carbon
    include FFWD::Plugin
    include FFWD::Logging

    register_plugin "carbon"

    DEFAULT_HOST = "localhost"
    DEFAULT_PORT = 2003
    DEFAULT_PROTOCOL = "tcp"

    def self.setup_input opts, core
      opts[:host] ||= DEFAULT_HOST
      opts[:port] ||= DEFAULT_PORT
      protocol = FFWD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)
      protocol.bind opts, core, log, Connection
    end

    def self.setup_tunnel opts, core, tunnel
      opts[:port] ||= DEFAULT_PORT
      protocol = FFWD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)
      protocol.tunnel opts, core, tunnel, log, Connection
    end
  end
end
