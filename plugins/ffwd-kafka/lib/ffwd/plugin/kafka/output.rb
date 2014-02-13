require 'ffwd/logging'
require 'ffwd/producing_client'

require_relative 'zookeeper_client'
require_relative 'zookeeper_functions'
require_relative 'producer'

module FFWD::Plugin::Kafka
  class Output < FFWD::ProducingClient
    include FFWD::Logging
    include FFWD::Plugin::Kafka::ZookeeperFunctions

    attr_reader :reporter_id

    MAPPING = [:host, :ttl, :key, :time, :value, :tags, :attributes]

    def initialize(core, zookeeper_url, producer, event_topic, metric_topic,
                   brokers, flush_period, flush_size, event_limit, metric_limit)

      super log, flush_period, flush_size, event_limit, metric_limit

      unless zookeeper_url.nil?
        @zookeeper = ZookeeperClient.new(zookeeper_url)
      end

      @producer = producer
      @event_topic = event_topic
      @metric_topic = metric_topic
      @brokers = brokers
      @producer_instance = nil
      @reporter_id = "kafka/#{@producer}/#{@event_topic}:#{@metric_topic}"

      if @zookeeper
        make_zk_kafka_producer
      else
        @producer = make_kafka_producer
      end

      run core.output
    end

    def produce events, metrics
      unless @producer_instance
        return nil
      end

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
end
