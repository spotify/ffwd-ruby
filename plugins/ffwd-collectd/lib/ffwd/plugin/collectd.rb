require 'ffwd/plugin'
require 'ffwd/protocol'
require 'ffwd/logging'

require_relative 'collectd/connection'
require_relative 'collectd/types_db'

module FFWD::Plugin::Collectd
  include FFWD::Plugin
  include FFWD::Logging

  register_plugin "collectd"

  DEFAULT_HOST = "localhost"
  DEFAULT_PORT = 25826
  DEFAULT_TYPES_DB = "/usr/share/collectd/types.db"

  def self.setup_input opts, core
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT
    opts[:types_db] ||= DEFAULT_TYPES_DB
    protocol = FFWD.parse_protocol(opts[:protocol] || "udp")
    types_db = TypesDB.open opts[:types_db]
    protocol.bind opts, core, log, Connection, types_db
  end

  def self.setup_tunnel opts, core, tunnel
    opts[:port] ||= DEFAULT_PORT
    opts[:types_db] ||= DEFAULT_TYPES_DB
    protocol = FFWD.parse_protocol(opts[:protocol] || "udp")
    protocol.tunnel log, opts, Connection
    types_db = TypesDB.open opts[:types_db]
    protocol.bind opts, core, tunnel, log, Connection, types_db
  end
end
