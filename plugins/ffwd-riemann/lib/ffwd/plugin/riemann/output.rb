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

require 'ffwd/handler'

require_relative 'shared'

module FFWD::Plugin::Riemann
  class Output < FFWD::Handler
    include FFWD::Plugin::Riemann::Shared

    def initialize connection, chunk_size
      super connection
      @chunk_size = chunk_size
    end

    def send_all events, metrics
      all_events = []
      all_events += events.map{|e| make_event e} unless events.empty?
      all_events += metrics.map{|m| make_metric m} unless metrics.empty?

      if all_events.empty?
        return
      end

      split_chunks(all_events) do |chunked_events|
        send_data encode(make_message :events => chunked_events)
      end
    end

    def send_event event
      e = make_event event
      m = make_message :events => [e]
      send_data encode(m)
    end

    def send_metric metric
      e = make_metric metric
      m = make_message :events => [e]
      send_data encode(m)
    end

    # When output plugins received data, assume that it is receiving an ACK.
    def receive_data data
      message = read_message data
      return if message.ok
      @bad_acks = (@bad_acks || 0) + 1
    end

    private

    def split_chunks all_events
      if @chunk_size.nil?
        yield all_events
        return
      end

      all_events.each_slice(@chunk_size) do |slice|
        yield slice
      end
    end
  end
end

