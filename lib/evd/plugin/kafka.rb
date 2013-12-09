require 'evd/plugin'
require 'evd/logging'
require 'evd/zookeeper'
require 'evd/kafka'
require 'evd/reporter'
require 'evd/producing_client'

require 'evd/plugin/kafka/zookeeper'

module EVD::Plugin
  module Kafka
    include EVD::Plugin
    include EVD::Logging

    register_plugin "kafka"

    class Client < EVD::ProducingClient
      include EVD::Logging
      include EVD::Plugin::Kafka::Zookeeper

      MAPPING = [:host, :ttl, :key, :time, :value, :tags, :attributes]

      def initialize(zookeeper_url, producer, topic, brokers,
                     flush_period, flush_size, buffer_limit)
        super flush_period, flush_size, buffer_limit

        unless zookeeper_url.nil?
          @zookeeper = EVD::Zookeeper.new(zookeeper_url)
        end

        @kafka = EVD::Kafka.new
        @producer = producer
        @topic = topic
        @brokers = brokers
      end

      def id
        @producer
      end

      def produce(buffer)
        messages = buffer.map{|e| make_message e}
        @kafka_producer.send_messages messages
      end

      def setup_producer
        return make_zk_kafka_producer if @zookeeper
        make_kafka_producer
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
            @kafka_producer = @kafka.producer brokers, @producer
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

        @kafka_producer = @kafka.producer @brokers, @producer
      end

      def make_message(event)
        ::EVD::Kafka::MessageToSend.new @topic, JSON.dump(make_hash event)
      end

      def make_hash(event)
        Hash[MAPPING.map{|k| if v = event.send(k); [k, v]; end}]
      end
    end

    DEFAULT_ZOOKEEPER_URL = "localhost:2181"
    DEFAULT_PRODUCER = "test"
    DEFAULT_TOPIC = "test"
    DEFAULT_BROKERS = ["localhost:9092"]
    DEFAULT_FLUSH_PERIOD = 10
    DEFAULT_BUFFER_LIMIT = 10000
    DEFAULT_FLUSH_SIZE = 1000

    def self.output_setup(opts={})
      zookeeper_url = opts[:zookeeper_url] || DEFAULT_ZOOKEEPER_URL
      producer = opts[:producer] || DEFAULT_PRODUCER
      topic = opts[:topic] || DEFAULT_TOPIC
      brokers = opts[:brokers] || DEFAULT_BROKERS
      flush_period = opts[:flush_period] || DEFAULT_FLUSH_PERIOD
      flush_size = opts[:flush_size] || DEFAULT_FLUSH_SIZE
      buffer_limit = opts[:buffer_limit] || DEFAULT_BUFFER_LIMIT

      if flush_period <= 0
        raise "Invalid flush period: #{flush_period}"
      end

      Client.new zookeeper_url, producer, topic, brokers,
                 flush_period, flush_size, buffer_limit
    end
  end
end
