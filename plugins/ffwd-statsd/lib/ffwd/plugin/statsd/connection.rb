require 'ffwd/logging'
require 'ffwd/connection'

require_relative 'parser'

module FFWD::Plugin::Statsd
  class Connection < FFWD::Connection
    include FFWD::Logging

    def self.plugin_type
      "statsd_in"
    end

    def initialize bind, core
      @bind = bind
      @core = core
    end

    def receive_data(data)
      metric = Parser.parse(data)
      return if metric.nil?
      @core.input.metric metric
      @bind.increment :received_metrics
    rescue => e
      log.error "Failed to receive data", e
    end
  end
end
