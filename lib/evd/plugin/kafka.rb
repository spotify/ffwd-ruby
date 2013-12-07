require 'evd/plugin'
require 'evd/logging'
require 'evd/zookeeper'
require 'evd/em_ext'

require 'evd/plugin/kafka/zookeeper'

module EVD::Plugin
  module Kafka
    include EVD::Plugin
    include EVD::Logging

    register_plugin "kafka"

    class Client
      include EVD::Logging
      include EVD::Plugin::Kafka::Zookeeper

      def initialize(zk_url)
        @zk = EVD::Zookeeper.new(zk_url) unless zk_url.nil?
      end

      def start(channel)
        if @zk
          req = zk_find_broker @zk

          req.callback do |broker|
            log.info "Connect to: #{broker}"
          end

          req.errback do
            log.error "Failed to find broker"
          end
        end
      end
    end

    DEFAULT_URL = "localhost:2181"

    def self.output_setup(opts={})
      zk_url = opts[:zk_url] || DEFAULT_URL
      Client.new zk_url
    end
  end
end
