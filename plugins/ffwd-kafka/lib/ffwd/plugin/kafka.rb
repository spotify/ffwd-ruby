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
require 'ffwd/plugin'
require 'ffwd/producing_client'
require 'ffwd/reporter'
require 'ffwd/schema'

require_relative 'kafka/output'
require_relative 'kafka/partitioners'
require_relative 'kafka/routers'

module FFWD::Plugin
  module Kafka
    include FFWD::Plugin
    include FFWD::Logging

    register_plugin "kafka",
      :description => "A plugin for the collectd binary protocol.",
      :options => [
        FFWD::Plugin.option(
          :producer, :default => FFWD::Plugin::Kafka::Output::DEFAULT_PRODUCER,
          :help => ["Name of the producer."]
        ),
        FFWD::Plugin.option(
          :port, :default => FFWD::Plugin::Kafka::Output::DEFAULT_BROKERS,
          :help => ["Brokers to connect to."]
        ),
        FFWD::Plugin.option(
          :partitioner, :default => FFWD::Plugin::Kafka::DEFAULT_PARTITIONER,
          :help => [
            "Partitioner to use, the partitioner decides what partition key is used for a specific message.",
            ":host - Base partition key of the host of the event/metric.",
            ":key - Base partition key of the key of the event/metric.",
            ":attribute - Base partition key of a specific attribute of the event/metric."
          ]
        ),
        FFWD::Plugin.option(
          :router, :default => FFWD::Plugin::Kafka::DEFAULT_ROUTER,
          :help => [
            "Router to use, the router decides which topic to use for a specific message." 
          ]
        ),
      ] +
      FFWD::Plugin::Kafka::AttributePartitioner::OPTIONS +
      FFWD::Plugin::Kafka::AttributeRouter::OPTIONS

    class Setup
      attr_reader :config

      def initialize config
        @config = Output.prepare Hash[config]
        @config = FFWD.prepare_schema @config
        @config[:partitioner] = FFWD::Plugin::Kafka.prepare_partitioner(
          @config[:partitioner] || {})
        @config[:router] = FFWD::Plugin::Kafka.prepare_router(
          @config[:router] || {})
      end

      def connect core
        partitioner = FFWD::Plugin::Kafka.build_partitioner @config[:partitioner]
        router = FFWD::Plugin::Kafka.build_router @config[:router]
        schema = FFWD.parse_schema @config
        output = Output.new schema, router, partitioner, @config
        FFWD.producing_client core.output, output, @config
      end
    end

    def self.setup_output config
      Setup.new config
    end
  end
end
