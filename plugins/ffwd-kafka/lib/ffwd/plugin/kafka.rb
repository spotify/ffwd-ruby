require 'ffwd/logging'
require 'ffwd/plugin'
require 'ffwd/producing_client'
require 'ffwd/reporter'

require_relative 'kafka/output'

module FFWD::Plugin
  module Kafka
    include FFWD::Plugin
    include FFWD::Logging

    register_plugin "kafka"

    DEFAULT_ZOOKEEPER_URL = "localhost:2181"
    DEFAULT_PRODUCER = "ffwd"
    DEFAULT_TOPIC = "ffwd"
    DEFAULT_BROKERS = ["localhost:9092"]

    def self.setup_output opts, core
      zookeeper_url = opts[:zookeeper_url] || DEFAULT_ZOOKEEPER_URL
      producer = opts[:producer] || DEFAULT_PRODUCER
      event_topic = opts[:event_topic] || DEFAULT_TOPIC
      metric_topic = opts[:metric_topic] || DEFAULT_TOPIC
      brokers = opts[:brokers] || DEFAULT_BROKERS

      producer = Output.new zookeeper_url, producer, event_topic, metric_topic, brokers
      FFWD.producing_client core.output, producer, opts
    end
  end
end
