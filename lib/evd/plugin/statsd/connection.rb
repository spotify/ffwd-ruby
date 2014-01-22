require 'evd/logging'
require 'evd/connection'

require_relative 'parser'

module EVD::Plugin::Statsd
  class Connection < EVD::Connection
    include EVD::Logging

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
