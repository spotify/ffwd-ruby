require 'evd/plugin'
require 'evd/logging'

module EVD::Plugin
  module Kafka
    include EVD::Plugin
    include EVD::Logging

    register_plugin "kafka"

    def self.output_setup(opts={})
      throw Exception.new("Not supported")
    end
  end
end
