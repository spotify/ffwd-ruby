require 'evd/plugin'
require 'evd/logging'
require 'evd/zookeeper'
require 'evd/kafka'
require 'evd/reporter'

require 'evd/plugin/kafka/zookeeper'

module EVD::Plugin
  module Kafka
    include EVD::Plugin
    include EVD::Logging

    register_plugin "kafka"

    class Client
      include EVD::Logging
      include EVD::Plugin::Kafka::Zookeeper
      include EVD::Reporter

      MAPPING = [:host, :ttl, :key, :time, :value, :tags, :attributes]

      def initialize(zookeeper_url, producer, topic, brokers, flush_period)
        unless zookeeper_url.nil?
          @zookeeper = EVD::Zookeeper.new(zookeeper_url)
        end

        @kafka = EVD::Kafka.new
        @producer = producer
        @topic = topic
        @brokers = brokers
        @flush_period = flush_period
        @buffer = []
        @kafka_producer = nil
      end

      def id
        @producer
      end

      def start(channel)
        if @zookeeper
          make_zk_kafka_producer
        else
          make_kafka_producer
        end

        if @flush_period > 0
          EM::PeriodicTimer.new(@flush_period){flush!}
          channel.subscribe{|e| @buffer << e}
        else
          channel.subscribe{|e| handle_event e}
        end
      end

      private

      def make_zk_kafka_producer
        req = zk_find_brokers log, @zookeeper

        req.callback do |brokers|
          if brokers.empty?
            log.error "Could not discover any brokers"
          else
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

      def flush!
        return increment :dropped, @buffer.size unless @kafka_producer
        messages = @buffer.map{|event| make_message}
        @kafka_producer.send_messages messages
      rescue => e
        log.error "Failed to flush messages", e
      ensure
        @buffer.clear
      end

      def handle_event(event)
        return increment :dropped, 1 unless @kafka_producer
        @kafka_producer.send_messages [make_message(event)]
      rescue => e
        log.error "Failed to send message", e
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

    def self.output_setup(opts={})
      zookeeper_url = opts[:zookeeper_url] || DEFAULT_ZOOKEEPER_URL
      producer = opts[:producer] || DEFAULT_PRODUCER
      topic = opts[:topic] || DEFAULT_TOPIC
      brokers = opts[:brokers] || DEFAULT_BROKERS
      flush_period = opts[:flush_period] || DEFAULT_FLUSH_PERIOD
      Client.new zookeeper_url, producer, topic, brokers, flush_period
    end
  end
end
