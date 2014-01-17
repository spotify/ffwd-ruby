require 'eventmachine'
require 'set'

require_relative '../protocol'
require_relative '../plugin'
require_relative '../logging'

require_relative 'json_line/connection'

module EVD::Plugin::JsonLine
  include EVD::Plugin
  include EVD::Logging

  register_plugin "json_line"

  DEFAULT_HOST = "localhost"
  DEFAULT_PORT = 3000

  def self.setup_input core, opts={}
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT
    buffer_limit = opts["buffer_limit"] || 1000
    protocol = EVD.parse_protocol(opts[:protocol] || "tcp")
    protocol.bind log, opts, Connection, buffer_limit
  end
end
