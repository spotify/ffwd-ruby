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

require_relative '../lifecycle'

module FFWD::Debug
  class MonitorSession
    attr_reader :id

    def initialize id, channel, type
      @type = type
      @clients = {}

      subs = []

      channel.starting do
        subs << channel.event_subscribe do |event|
          data = @type.serialize_event event

          begin
            send JSON.dump(:id => @id, :type => :event, :data => data)
          rescue => e
            log.error "Failed to serialize event", e
            return
          end
        end

        subs << channel.metric_subscribe do |metric|
          data = @type.serialize_metric metric

          begin
            send JSON.dump(:id => @id, :type => :metric, :data => data)
          rescue => e
            log.error "Failed to serialize metric", e
            return
          end
        end
      end

      channel.stopping do
        subs.each(&:unsubscribe).clear
      end
    end

    def register peer, client
      @clients[peer] = client
    end

    def unregister peer, client
      @clients.delete peer
    end

    def send line
      @clients.each do |peer, client|
        client.send_line line
      end
    end
  end
end
