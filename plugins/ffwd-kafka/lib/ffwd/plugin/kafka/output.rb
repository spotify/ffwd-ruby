# $LICENSE
# Copyright 2013-2014 Spotify AB. All rights reserved.
#
# The contents of this file are licensed under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with the
# License. You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

require 'ffwd/logging'
require 'ffwd/producing_client'

require_relative 'producer'

module FFWD::Plugin::Kafka
  class Output < FFWD::ProducingClient::Producer
    include FFWD::Logging
    include FFWD::Reporter

    report_meta :component => :kafka

    report_key :kafka_routing_error, :meta => {:what => :kafka_routing_error, :unit => :failure}
    report_key :kafka_routing_success, :meta => {:what => :kafka_routing_success, :unit => :success}

    attr_reader :reporter_meta

    MAPPING = [:host, :ttl, :key, :time, :value, :tags, :attributes]

    DEFAULT_PRODUCER = "ffwd"
    DEFAULT_BROKERS = ["localhost:9092"]

    def self.prepare config
      config[:producer] ||= DEFAULT_PRODUCER
      config[:brokers] ||= DEFAULT_BROKERS
      config
    end

    def initialize schema, router, partitioner, config
      @schema = schema
      @router = router
      @partitioner = partitioner
      @producer = config[:producer]
      @brokers = config[:brokers]
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
