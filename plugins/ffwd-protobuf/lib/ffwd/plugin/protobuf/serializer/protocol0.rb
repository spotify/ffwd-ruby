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

    def self.load string
      message = P::Message.new
      message.parse_from_string string

      if message.has_field?(:event)
        yield :event, receive_event(message.event)
      end

      if message.has_field?(:metric)
        yield :metric, receive_metric(message.metric)
      end
    end

    def self.receive_event e
      d = {}
      d[:time] = Time.at(e.time.to_f / 1000) if e.has_field?(:time)
      d[:key] = e.key if e.has_field?(:key)
      d[:value] = e.value if e.has_field?(:value)
      d[:host] = e.host if e.has_field?(:host)
      d[:state] = e.state if e.has_field?(:state)
      d[:description] = e.description if e.has_field?(:description)
      d[:ttl] = e.ttl if e.has_field?(:ttl)
      d[:tags] = from_tags e.tags if e.tags
      d[:attributes] = from_attributes e.attributes if e.attributes
      return d
    end

    def self.receive_metric m
      d = {}
      d[:proc] = m.host if m.has_field?(:proc)
      d[:time] = Time.at(m.time.to_f / 1000) if m.has_field?(:time)
      d[:key] = m.key if m.has_field?(:key)
      d[:value] = m.value if m.has_field?(:value)
      d[:host] = m.host if m.has_field?(:host)
      d[:tags] = from_tags m.tags if m.tags
      d[:attributes] = from_attributes m.attributes if m.attributes
      return d
    end

    def self.from_attributes attributes
      Hash[attributes.map{|a| [a.key, a.value]}]
    end

    def self.from_tags tags
      Array.new tags
    end

    def self.dump_event event
      e = P::Event.new
      e.time = (event.time.to_f * 1000).to_i if event.time
      e.key = event.key if event.key
      e.value = event.value.to_f if event.value
      e.host = event.host if event.host
      e.state = event.state if event.state
      e.description = event.description if event.description
      e.ttl = event.ttl if event.ttl
      e.tags = to_tags event.tags if event.tags
      e.attributes = to_attributes event.attributes if event.attributes

      message = P::Message.new
      message.event = e
      message.serialize_to_string
    end

    def self.dump_metric metric
      m = P::Metric.new
      m.time = (metric.time.to_f * 1000).to_i if metric.time
      m.key = metric.key if metric.key
      m.value = metric.value.to_f if metric.value
      m.host = metric.host if metric.host
      m.tags = to_tags metric.tags if metric.tags
      m.attributes = to_attributes metric.attributes if metric.attributes

      message = P::Message.new
      message.metric = m
      message.serialize_to_string
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
