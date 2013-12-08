require 'evd/plugin'
require 'evd/logging'
require 'evd/zookeeper'
require 'evd/kafka'

require 'evd/plugin/kafka/zookeeper'

module EVD::Plugin
  module Kafka
    include EVD::Plugin
    include EVD::Logging

    register_plugin "kafka"

    class Client
      include EVD::Logging
      include EVD::Plugin::Kafka::Zookeeper

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
        @dropped = 0
      end

      def report?
        @dropped > 0
      end

      def report
        if @dropped > 0
          log.warning "Dropped #{@dropped} event(s)"
          @dropped = 0
        end
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
        unless @kafka_producer
          @dropped += @buffer.size
          return
        end

        messages = @buffer.map{|event| make_message}
        @kafka_producer.send_messages messages
      rescue => e
        log.error "Failed to flush messages", e
      ensure
        @buffer.clear
      end

      def handle_event(event)
        unless @kafka_producer
          @dropped += 1
          return
        end

        @kafka_producer.send_messages [make_message(event)]
      end

      def make_message(event)
        ::EVD::Kafka::MessageToSend.new @topic, JSON.dump(make_hash event)
      end

      def make_hash(event)
        o = {}

        MAPPING.map do |key|
          next if (v = event.send(key)).nil?
          o[key] = v
        end

        return o
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
