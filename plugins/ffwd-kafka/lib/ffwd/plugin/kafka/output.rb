require 'ffwd/logging'
require 'ffwd/producing_client'

require_relative 'producer'

module FFWD::Plugin::Kafka
  class Output < FFWD::ProducingClient::Producer
    include FFWD::Logging
    include FFWD::Reporter

    setup_reporter :keys => [:kafka_routing_error, :kafka_routing_success]

    attr_reader :reporter_meta

    MAPPING = [:host, :ttl, :key, :time, :value, :tags, :attributes]

    def initialize producer, brokers, schema, router, partitioner
      @producer = producer
      @brokers = brokers
      @schema = schema
      @router = router
      @partitioner = partitioner
      @reporter_meta = {:producer_type => "kafka", :producer => @producer}
      @instance = nil
    end

    def setup
      if not @brokers or @brokers.empty?
        log.error "No usable initial list of brokers"
        return
      end

      @instance = Producer.new @brokers, @producer
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

      expected_messages = events.size + metrics.size
      messages = []

      events.each do |e|
        message = make_event_message e
        next if message.nil?
        messages << message
      end

      metrics.each do |e|
        message = make_metric_message e
        next if message.nil?
        messages << message
      end

      if messages.size < expected_messages
        increment :kafka_routing_error, expected_messages - messages.size
      end

      increment :kafka_routing_success, messages.size
      @instance.send_messages messages
    end

    def make_event_message e
      topic = @router.route_event e
      return nil if topic.nil?
      data = @schema.dump_event e
      key = @partitioner.partition e
      MessageToSend.new topic, data, key
    end

    def make_metric_message m
      topic = @router.route_metric m
      return nil if topic.nil?
      data = @schema.dump_metric m
      key = @partitioner.partition m
      MessageToSend.new topic, data, key
    end
  end
end
