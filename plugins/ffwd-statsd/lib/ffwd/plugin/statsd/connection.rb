require 'ffwd/logging'
require 'ffwd/connection'

require_relative 'parser'

module FFWD::Plugin::Statsd
  class Connection < FFWD::Connection
    include FFWD::Logging

    def initialize core
      @core = core
    end

    def receive_data(data)
      metric = Parser.parse(data)
      return if metric.nil?
      @core.input.metric metric
    rescue => e
      log.error "Failed to receive data", e
    end
  end
end
