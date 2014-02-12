require 'ffwd/logging'
require 'ffwd/connection'

require_relative 'parser'

module FFWD::Plugin::Statsd
  class Connection < FFWD::Connection
    include FFWD::Logging

    def initialize input, output
      @input = input
    end

    def receive_data(data)
      metric = Parser.parse(data)
      return if metric.nil?
      @input.metric metric
    rescue => e
      log.error "Failed to receive data", e
    end
  end
end
