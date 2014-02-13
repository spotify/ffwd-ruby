require 'eventmachine'
require 'em-http'

require 'ffwd/logging'
require 'ffwd/plugin'
require 'ffwd/reporter'

require_relative 'kairosdb/output'

module FFWD::Plugin::KairosDB
  include FFWD::Plugin
  include FFWD::Logging

  register_plugin "kairosdb"

  DEFAULT_URL = "http://localhost:8080"
  DEFAULT_FLUSH_INTERVAL = 10
  DEFAULT_BUFFER_LIMIT = 100000

  def self.setup_output opts, core
    url = opts[:url] || DEFAULT_URL
    flush_interval = opts[:flush_interval] || DEFAULT_FLUSH_INTERVAL
    buffer_limit = opts[:buffer_limit] || DEFAULT_BUFFER_LIMIT
    Output.new core, log, url, flush_interval, buffer_limit
  end
end
