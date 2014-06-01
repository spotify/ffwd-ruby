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

require 'eventmachine'

require 'ffwd/logging'
require 'ffwd/connection'

module FFWD::Plugin::JSON
  class Connection < FFWD::Connection
    include FFWD::Logging

    EVENT_FIELDS = [
      ["key", :key],
      ["value", :value],
      ["host", :host],
      ["state", :state],
      ["description", :description],
      ["ttl", :ttl],
      ["tags", :tags],
      ["attributes", :attributes],
    ]

    METRIC_FIELDS = [
      ["proc", :proc],
      ["key", :key],
      ["value", :value],
      ["tags", :tags],
      ["attributes", :attributes]
    ]

    def initialize bind, core, config
      @bind = bind
      @core = core
    end

    def receive_json data
      data = JSON.load(data)

      unless type = data["type"]
        log.error "Field 'type' missing from received line"
        return
      end

      if type == "metric"
        @core.input.metric read_metric(data)
        @bind.increment :received_metrics
        return
      end

      if type == "event"
        @core.input.event read_event(data)
        @bind.increment :received_events
        return
      end

      log.error "No such type: #{type}"
    rescue => e
      log.error "Failed to receive line", e
    end

    def read_tags d, source
      return if (tags = d["tags"]).nil?
      d[:tags] = tags.to_set
    end

    def read_time d, source
      return if (time = d["time"]).nil?
      d[:time] = Time.at time
    end

    def read_metric data
      d = {}

      read_tags d, data["tags"]
      read_time d, data["time"]

      METRIC_FIELDS.each do |from, to|
        next if (v = data[from]).nil?
        d[to] = v
      end

      d
    end

    def read_event data
      d = {}

      read_tags d, data["tags"]
      read_time d, data["time"]

      EVENT_FIELDS.each do |from, to|
        next if (v = data[from]).nil?
        d[to] = v
      end

      d
    end
  end
end
