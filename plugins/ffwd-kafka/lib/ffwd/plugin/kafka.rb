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

    register_plugin "kafka"

    DEFAULT_PRODUCER = "ffwd"
    DEFAULT_ROUTING_METHOD = :attribute
    DEFAULT_ROUTING_KEY = :site
    DEFAULT_BROKERS = ["localhost:9092"]
    DEFAULT_PARTITIONER = :host
    DEFAULT_ROUTER = :attribute

    def self.setup_output opts, core
      producer = opts[:producer] || DEFAULT_PRODUCER
      brokers = opts[:brokers] || DEFAULT_BROKERS
      partitioner = FFWD::Plugin::Kafka.build_partitioner(
        opts[:partitioner] || DEFAULT_PARTITIONER, opts)
      router = FFWD::Plugin::Kafka.build_router(
        opts[:router] || DEFAULT_ROUTER, opts)
      schema = FFWD.parse_schema opts

      producer = Output.new producer, brokers, schema, router, partitioner
      FFWD.producing_client core.output, producer, opts
    end
  end
end
