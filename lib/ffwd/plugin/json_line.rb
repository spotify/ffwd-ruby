require 'eventmachine'

require 'ffwd/protocol'
require 'ffwd/plugin'
require 'ffwd/logging'

require_relative 'json_line/connection'

module FFWD::Plugin::JsonLine
  include FFWD::Plugin
  include FFWD::Logging

  register_plugin "json_line"

  DEFAULT_HOST = "localhost"
  DEFAULT_PORT = 3000

  def self.setup_input opts, core
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT
    buffer_limit = opts["buffer_limit"] || 1000
    protocol = FFWD.parse_protocol(opts[:protocol] || "tcp")
    protocol.bind opts, core, log, Connection, buffer_limit
  end
end
