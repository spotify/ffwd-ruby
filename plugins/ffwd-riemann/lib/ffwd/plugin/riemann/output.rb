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

require_relative 'shared'

module FFWD::Plugin::Riemann
  module Output
    def send_all events, metrics
      all_events = []

      events.each do |event|
        begin
          all_events << make_event(event)
        rescue => error
          output_failed_event event, error
        end
      end

      metrics.each do |metric|
        begin
          all_events << make_metric(metric)
        rescue => error
          output_failed_metric metric, error
        end
      end

      return if all_events.empty?

      m = make_message :events => all_events
      send_data output_encode(m)
    end

    def send_event event
      begin
        e = make_event event
      rescue => error
        output_failed_event event, error
        return
      end

      m = make_message :events => [e]
      send_data output_encode(m)
    end

    def send_metric metric
      begin
        e = make_metric metric
      rescue => error
        output_failed_metric event, error
        return
      end

      m = make_message :events => [e]
      send_data output_encode(m)
    end

    def receive_data data
      message = read_message data
      return if message.ok
      @bad_acks = (@bad_acks || 0) + 1
    end

    def output_encode message
      raise "#output_encode: not implemented"
    end

    def output_failed_event event, error; end
    def output_failed_metric metric, error; end
  end
end

