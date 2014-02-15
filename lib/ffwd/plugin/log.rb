require 'ffwd/event'
require 'ffwd/logging'
require 'ffwd/metric'
require 'ffwd/plugin'

require_relative 'log/writer'

module FFWD::Plugin
  module Log
    include FFWD::Plugin
    include FFWD::Logging

    register_plugin "log"

    def self.setup_output opts, core
      prefix = opts[:prefix]
      Writer.new core, prefix
    end
  end
end
