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
    DEFAULT_PRODUCER = "test"
    DEFAULT_TOPIC = "test"
    DEFAULT_BROKERS = ["localhost:9092"]
    DEFAULT_FLUSH_PERIOD = 10
    DEFAULT_EVENT_LIMIT = 10000
    DEFAULT_METRIC_LIMIT = 10000
    DEFAULT_FLUSH_SIZE = 1000

    def self.setup_output opts, core
      zookeeper_url = opts[:zookeeper_url] || DEFAULT_ZOOKEEPER_URL
      producer = opts[:producer] || DEFAULT_PRODUCER
      event_topic = opts[:event_topic] || DEFAULT_TOPIC
      metric_topic = opts[:metric_topic] || DEFAULT_TOPIC
      brokers = opts[:brokers] || DEFAULT_BROKERS
      flush_period = opts[:flush_period] || DEFAULT_FLUSH_PERIOD
      flush_size = opts[:flush_size] || DEFAULT_FLUSH_SIZE
      event_limit = opts[:event_limit] || DEFAULT_EVENT_LIMIT
      metric_limit = opts[:metric_limit] || DEFAULT_METRIC_LIMIT

      if flush_period <= 0
        raise "Invalid flush period: #{flush_period}"
      end

      Output.new core, zookeeper_url, producer, event_topic, metric_topic,
                 brokers, flush_period, flush_size, event_limit, metric_limit
    end
  end
end
