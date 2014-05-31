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

require 'ffwd/protocol0.pb'

module FFWD
  module Plugin
    module Protobuf
      module Serializer
      end
    end
  end
end

module FFWD::Plugin::Protobuf::Serializer
  module Protocol0
    P = ::FFWD::Protocol0

    METRIC_FIELDS = [:key, :value, :host]
    EVENT_FIELDS = [:key, :value, :host, :state, :description, :ttl]

    def self.load string
      message = P::Message.decode(string)

      if message.event
        yield :event, receive_event(message.event)
      end

      if message.metric
        yield :metric, receive_metric(message.metric)
      end
    end

    def self.map_fields fields, s
      Hash[fields.map{|f| [f, s.send(f)]}.reject{|f, v| v.nil?}]
    end

    def self.receive_event event
      d = map_fields EVENT_FIELDS, event
      d[:time] = Time.at(event.time.to_f / 1000) if event.time
      d[:tags] = from_tags event.tags if event.tags
      d[:attributes] = from_attributes event.attributes if event.attributes
      return d
    end

    def self.receive_metric metric
      d = map_fields METRIC_FIELDS, metric
      d[:proc] = metric.proc if metric.proc
      d[:time] = Time.at(metric.time.to_f / 1000) if metric.time
      d[:tags] = from_tags metric.tags if metric.tags
      d[:attributes] = from_attributes metric.attributes if metric.attributes
      return d
    end

    def self.from_attributes source
      Hash[source.map{|a| [a.key, a.value]}]
    end

    def self.from_tags source
      Array.new source
    end

    def self.dump_event event
      e = P::Event.new map_fields(EVENT_FIELDS, event)
      e.time = (event.time.to_f * 1000).to_i if event.time
      e.tags = to_tags event.tags if event.tags
      e.attributes = to_attributes event.attributes if event.attributes
      P::Message.new(:event => e).encode
    end

    def self.dump_metric metric
      m = P::Metric.new map_fields(METRIC_FIELDS, metric)
      m.time = (metric.time.to_f * 1000).to_i if metric.time
      m.tags = to_tags metric.tags if metric.tags
      m.attributes = to_attributes metric.attributes if metric.attributes
      P::Message.new(:metric => m).encode
    end

    private

    def self.to_attributes attributes
      attributes.map do |key, value|
        P::Attribute.new(:key => key.to_s, :value => value.to_s)
      end
    end

    def self.to_tags tags
      Array.new tags
    end
  end
end
