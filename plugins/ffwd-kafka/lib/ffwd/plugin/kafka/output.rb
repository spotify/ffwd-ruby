require 'ffwd/logging'
require 'ffwd/producing_client'

require_relative 'zookeeper_client'
require_relative 'zookeeper_functions'
require_relative 'producer'

module FFWD::Plugin::Kafka
  class Output < FFWD::ProducingClient::Producer
    include FFWD::Logging
    include FFWD::Plugin::Kafka::ZookeeperFunctions

    attr_reader :reporter_meta

    MAPPING = [:host, :ttl, :key, :time, :value, :tags, :attributes]

    def initialize schema, zookeeper_url, producer, event_topic, metric_topic, brokers
      unless zookeeper_url.nil?
        @zookeeper = ZookeeperClient.new(zookeeper_url)
      end

      @schema = schema
      @producer = producer
      @event_topic = event_topic
      @metric_topic = metric_topic
      @brokers = brokers
      @reporter_meta = {
        :type => "kafka_out", :producer => @producer,
        :event_topic => @event_topic, :metric_topic => @metric_topic,
      }

      @instance = nil
    end

    def setup
      if @zookeeper
        make_zk_kafka_producer
      else
        make_kafka_producer
      end
    end

    def teardown
      if @instance
        @instance.stop
        @instance = nil
      end
    end

    def produce events, metrics
      unless @instance
        return nil
      end

      messages = []
      messages += events.map{|e| make_event_message e}
      messages += metrics.map{|e| make_metric_message e}

      @instance.send_messages messages
    end

    def make_zk_kafka_producer
      req = zk_find_brokers log, @zookeeper

      req.callback do |brokers|
        if brokers.empty?
          log.error "Zookeeper: Could not discover any brokers"
        else
          log.info "Zookeeper: Discovered brokers: #{brokers}"
          brokers = brokers.map{|b| "#{b[:host]}:#{b[:port]}"}
          @instance = Producer.new brokers, @producer
        end
      end

      req.errback do |e|
        # Do not log backtrace since this will be common when the zookeeper
        # broker is not running.
        if e.is_a? ZookeeperClient::ContinuationTimeoutError
          log.error "Failed to find brokers, request timed out: #{e}"
        else
          log.error "Failed to find brokers", e
        end

        log.info "Retrying zookeeper request for brokers"
        make_zk_kafka_producer
      end
    end

    def make_kafka_producer
      if not @brokers or @brokers.empty?
        log.error "No usable initial list of brokers"
        return
      end

      @instance = Producer.new @brokers, @producer
    end

    def make_event_message(e)
      MessageToSend.new @event_topic, @schema.dump_event(e)
    end

    def make_metric_message(m)
      MessageToSend.new @metric_topic, @schema.dump_metric(m)
    end
  end
end
