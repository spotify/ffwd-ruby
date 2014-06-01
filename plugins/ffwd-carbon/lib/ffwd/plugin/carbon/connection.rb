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

require 'ffwd/connection'

module FFWD::Plugin
  module Carbon
    class Connection < FFWD::Connection
      include EM::Protocols::LineText2

      def initialize bind, core, config
        @bind = bind
        @core = core
      end

      def parse line
        path, value, timestamp = line.split ' ', 3
        raise "invalid frame" if timestamp.nil?

        return nil if path.empty? or value.empty? or timestamp.empty?

        value = value.to_f unless value.nil?
        time = Time.at(timestamp.to_i)

        return {:key => path, :value => value, :time => time}
      end

      def receive_line line
        metric = parse line
        return if metric.nil?
        @core.input.metric metric
        @bind.increment :received_metrics
      rescue => e
        @bind.log.error "Failed to receive data", e
      end
    end
  end
end
