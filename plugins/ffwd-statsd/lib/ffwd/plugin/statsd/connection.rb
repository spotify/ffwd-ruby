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
require 'ffwd/connection'

require_relative 'parser'

module FFWD::Plugin::Statsd
  module Connection
    module ConnectionBase
      def receive_statsd_frame(data)
        metric = Parser.parse(data)
        return if metric.nil?
        @core.input.metric metric
        @bind.increment :received_metrics
      rescue ParserError => e
        log.error "Invalid frame '#{data}': #{e}"
        @bind.increment :failed_metrics
      rescue => e
        log.error "Error when parsing metric '#{data}'", e
        @bind.increment :failed_metrics
      end
    end

    class UDP < FFWD::Connection
      include ConnectionBase
      include FFWD::Logging

      def initialize bind, core
        @bind = bind
        @core = core
      end

      def self.plugin_type
        "statsd_udp_in"
      end

      def receive_data data
        receive_statsd_frame data
      end
    end

    class TCP < FFWD::Connection
      include ConnectionBase
      include FFWD::Logging
      include EM::Protocols::LineText2

      def initialize bind, core
        @bind = bind
        @core = core
      end

      def self.plugin_type
        "statsd_tcp_in"
      end

      def receive_line(data)
        receive_statsd_frame data
      end
    end
  end
end
