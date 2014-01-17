require_relative '../kafka'
require_relative '../logging'
require_relative '../plugin'
require_relative '../producing_client'
require_relative '../reporter'
require_relative '../zookeeper'

require_relative 'kafka/zookeeper'

module EVD::Plugin
  module Kafka
    include EVD::Plugin
    include EVD::Logging

    register_plugin "kafka"

    class Client < EVD::ProducingClient
      include EVD::Logging
      include EVD::Plugin::Kafka::Zookeeper

      MAPPING = [:host, :ttl, :key, :time, :value, :tags, :attributes]

      def initialize(zookeeper_url, producer, event_topic, metric_topic,
                     brokers, flush_period, flush_size, event_limit, metric_limit)

        super flush_period, flush_size, event_limit, metric_limit

        unless zookeeper_url.nil?
          @zookeeper = EVD::Zookeeper.new(zookeeper_url)
        end

        @producer = producer
        @event_topic = event_topic
        @metric_topic = metric_topic
        @brokers = brokers
        @producer_instance = nil
      end

      def id
        @producer
      end

      def produce events, metrics
        return nil unless @producer_instance
        messages = (events.map{|e| make_event_message e} +
                    metrics.map{|e| make_metric_message e})
        @producer_instance.send_messages messages
      end

      def start *args
        if @zookeeper
          make_zk_kafka_producer
        else
          @producer = make_kafka_producer
        end

        super(*args)
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
            @producer_instance = EVD::Kafka::Producer.new brokers, @producer
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

        @producer_instance = EVD::Kafka::Producer.new @brokers, @producer
      end

      def make_event_message(e)
        ::EVD::Kafka::MessageToSend.new @event_topic, JSON.dump(EVD.event_to_h e)
      end

      def make_metric_message(m)
        ::EVD::Kafka::MessageToSend.new @metric_topic, JSON.dump(EVD.metric_to_h m)
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

    def self.setup_output core, opts={}
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

      Client.new zookeeper_url, producer, event_topic, metric_topic,
                 brokers, flush_period, flush_size, event_limit, metric_limit
    end
  end
end
