require 'evd/plugin'
require 'evd/protocol'
require 'evd/logging'

require_relative 'collectd/connection'
require_relative 'collectd/types_db'

module EVD::Plugin::Collectd
  include EVD::Plugin
  include EVD::Logging

  register_plugin "collectd"

  DEFAULT_HOST = "localhost"
  DEFAULT_PORT = 25826
  DEFAULT_TYPES_DB = "/usr/share/collectd/types.db"

  def self.setup_input core, opts={}
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT
    opts[:types_db] ||= DEFAULT_TYPES_DB
    protocol = EVD.parse_protocol(opts[:protocol] || "udp")
    types_db = TypesDB.open opts[:types_db]
    protocol.bind log, opts, Connection, types_db
  end

  def self.setup_tunnel core, opts={}
    opts[:port] ||= DEFAULT_PORT
    opts[:types_db] ||= DEFAULT_TYPES_DB
    protocol = EVD.parse_protocol(opts[:protocol] || "udp")
    protocol.tunnel log, opts, Connection
    types_db = TypesDB.open opts[:types_db]
    protocol.bind log, opts, Connection, types_db
  end
end
