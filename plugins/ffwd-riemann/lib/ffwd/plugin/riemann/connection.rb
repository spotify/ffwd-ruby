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

module FFWD::Plugin::Riemann
  module Connection
    module Serializer
      def self.dump(m)
        m.encode.to_s
      end

      def self.load(data)
        ::Riemann::Message.decode(data)
      end
    end

    def serializer
      FFWD::Plugin::Riemann::Connection::Serializer
    end

    def initialize bind, core, log
      @bind = bind
      @core = core
      @log = log
    end

    def receive_object(m)
      # handle no events in object.
      if m.events.nil?
        send_ok
        return
      end

      unless m.events.nil? or m.events.empty?
        events = m.events.map{|e| read_event(e)}
        events.each{|e| @core.input.event e}
      end

      @bind.increment :received_events, m.events.size
      send_ok
    rescue => e
      @bind.increment :failed_events, m.events.size
      @log.error "Failed to receive object", e
      send_error e
    end

    protected

    def send_ok; end
    def send_error(e); end
  end
end
