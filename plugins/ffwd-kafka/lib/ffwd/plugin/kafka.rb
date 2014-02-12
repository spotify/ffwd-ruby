require 'ffwd/logging'
require 'ffwd/plugin'
require 'ffwd/producing_client'
require 'ffwd/reporter'

require_relative 'kafka/producer'
require_relative 'kafka/zookeeper_functions'
require_relative 'kafka/zookeeper_client'

module FFWD::Plugin
  module Kafka
    include FFWD::Plugin
    include FFWD::Logging

    register_plugin "kafka"

    class Output < FFWD::ProducingClient
      include FFWD::Logging
      include FFWD::Plugin::Kafka::ZookeeperFunctions

      MAPPING = [:host, :ttl, :key, :time, :value, :tags, :attributes]

      def initialize(core, zookeeper_url, producer, event_topic, metric_topic,
                     brokers, flush_period, flush_size, event_limit, metric_limit)

        super flush_period, flush_size, event_limit, metric_limit

        unless zookeeper_url.nil?
          @zookeeper = ZookeeperClient.new(zookeeper_url)
        end

        @producer = producer
        @event_topic = event_topic
        @metric_topic = metric_topic
        @brokers = brokers
        @producer_instance = nil

        core.output.starting do
          if @zookeeper
            make_zk_kafka_producer
          else
            @producer = make_kafka_producer
          end

          run core.output

          core.output.stopping do
          end
        end
      end

      def id
        "#{self.class.name}(#{@producer}, #{@event_topic}, #{@metric_topic})"
      end

      def produce events, metrics
        return nil unless @producer_instance
        messages = (events.map{|e| make_event_message e} +
                    metrics.map{|e| make_metric_message e})
        @producer_instance.send_messages messages
      end

      private

      def make_zk_kafka_producer
        req = zk_find_brokers log, @zookeeper

        req.callback do |brokers|
          if brokers.empty?
            log.error "Zookeeper: Could not discover any brokers"
          else
            log.info "Zookeeper: Discovered brokers: #{brokers}"
            brokers = brokers.map{|b| "#{b[:host]}:#{b[:port]}"}
            @producer_instance = Producer.new brokers, @producer
          end
        end

        req.errback do |e|
          log.error "Failed to find brokers", e
        end
      end

      def make_kafka_producer
        if not @brokers or @brokers.empty?
          log.error "No usable initial list of brokers"
          return
        end

        @producer_instance = Producer.new @brokers, @producer
      end

      def make_event_message(e)
        ::FFWD::Kafka::MessageToSend.new @event_topic, JSON.dump(e.to_h)
      end

      def make_metric_message(m)
        ::FFWD::Kafka::MessageToSend.new @metric_topic, JSON.dump(m.to_h)
      end
    end

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
