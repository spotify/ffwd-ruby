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

      def initialize(zk_url, producer, topic, flush_period)
        @zookeeper = EVD::Zookeeper.new(zk_url) unless zk_url.nil?
        @kafka = EVD::Kafka.new
        @producer = producer
        @topic = topic
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
          req = find_brokers log, @zookeeper

          req.callback do |brokers|
            if brokers.empty?
              log.error "Could not discovery any brokers"
            else
              brokers = brokers.map{|b| "#{b[:host]}:#{b[:port]}"}
              @kafka_producer = @kafka.producer brokers, @producer
            end
          end

          req.errback do |e|
            log.error "Failed to find brokers", e
          end
        end

        EM::PeriodicTimer.new(@flush_period) do
          flush!
        end

        channel.subscribe do |event|
          @buffer << event
        end
      end

      def flush!
        unless @kafka_producer
          @dropped += @buffer.size
          return
        end

        messages = @buffer.map{|event|
          EVD::Kafka::MessageToSend.new @topic, JSON.dump(make_hash event)}
        @kafka_producer.send_messages messages
      rescue => e
        log.error "Failed to flush messages", e
      ensure
        @buffer.clear
      end

      private

      def make_hash(event)
        o = {}
        o[:host] = event[:host] if event[:host]
        o[:ttl] = event[:ttl] if event[:ttl]
        o[:key] = event[:key] if event[:key]
        o[:value] = event[:value] if event[:value]
        o[:tags] = event[:tags].to_a if event[:tags]
        o[:attributes] = event[:attributes] if event[:attributes]
        return o
      end

      def handle_event(event)
        return unless @kafka_producer
      end
    end

    DEFAULT_ZK_URL = "localhost:2181"
    DEFAULT_TOPIC = "test"
    DEFAULT_PRODUCER = "test"
    DEFAULT_FLUSH_PERIOD = 10

    def self.output_setup(opts={})
      zk_url = opts[:zk_url] || DEFAULT_ZK_URL
      topic = opts[:topic] || DEFAULT_TOPIC
      producer = opts[:producer] || DEFAULT_PRODUCER
      flush_period = opts[:flush_period] || DEFAULT_FLUSH_PERIOD
      Client.new zk_url, topic, producer, flush_period
    end
  end
end
