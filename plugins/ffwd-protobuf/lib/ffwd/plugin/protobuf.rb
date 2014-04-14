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

require 'ffwd/connection'
require 'ffwd/handler'
require 'ffwd/logging'
require 'ffwd/plugin'
require 'ffwd/protocol'
require 'ffwd/event'
require 'ffwd/metric'

require_relative 'protobuf/protocol.pb'

module FFWD::Plugin::Protobuf
  include FFWD::Plugin
  include FFWD::Logging

  P = ::FFWD::Plugin::Protobuf::Protocol

  register_plugin "protobuf"

  module Serializer
    def self.dump m
      m.serialize_to_string
    end

    def self.load string
      m = P::Message.new
      m.parse_from_string string
      return m
    end
  end

  class Output < FFWD::Handler
    include EM::Protocols::ObjectProtocol
    include Serializer

    def self.plugin_type
      "protobuf_out"
    end

    def serializer
      Serializer
    end

    def send_all events, metrics
      events.each do |event|
        send_event event
      end

      metrics.each do |metric|
        send_metric metric
      end
    end

    def send_event event
      message = P::Message.new
      e = P::Event.new
      e.time = (event.time.to_f * 1000).to_i if event.time
      e.key = event.key if event.key
      e.value = to_value event.value if event.value
      e.host = event.host if event.host
      e.source = event.source if event.source
      e.state = event.state if event.state
      e.description = event.description if event.description
      e.ttl = event.ttl if event.ttl
      e.tags = to_tags event.tags if event.tags
      e.attributes = to_attributes event.attributes if event.attributes
      message.event = e
      send_object message
    end

    def send_metric metric
      message = P::Message.new
      m = P::Metric.new
      m.time = (metric.time.to_f * 1000).to_i if metric.time
      m.key = metric.key if metric.key
      m.value = to_value metric.value if metric.value
      m.host = metric.host if metric.host
      m.source = metric.source if metric.source
      m.tags = to_tags metric.tags if metric.tags
      m.attributes = to_attributes metric.attributes if metric.attributes
      message.metric = m
      send_object message
    end

    private

    def to_value value
      v = P::Value.new
      v.value_d = value
      return v
    end

    def to_attributes attributes
      attributes.map do |key, value|
        P::Attribute.new(:key => key, :value => value)
      end
    end

    def to_tags tags
      Array.new tags
    end
  end

  class Input < FFWD::Connection
    include FFWD::Logging
    include EM::Protocols::ObjectProtocol

    def initialize bind, core, log
      @bind = bind
      @core = core
      @log = log
    end

    def self.plugin_type
      "protobuf_in"
    end

    def serializer
      Serializer
    end

    def receive_object message
      if e = message.event
        receive_event e
      end

      if m = message.metric
        receive_metric m
      end
    end

    def receive_event e
      d = {}
      d[:time] = Time.at(e.time.to_f / 1000) if e.time
      d[:key] = e.key if e.key
      d[:value] = from_value e.value if e.value
      d[:host] = e.host if e.host
      d[:source] = e.source if e.source
      d[:state] = e.state if e.state
      d[:description] = e.description if e.description
      d[:ttl] = e.ttl if e.ttl
      d[:tags] = from_tags m.tags if m.tags
      d[:attributes] = from_attributes m.attributes if m.attributes
      @core.input.event d
      @bind.increment :received_events
    rescue => e
      @log.error "Failed to receive event", e
      @bind.increment :failed_events
    end

    def receive_metric m
      d = {}
      d[:time] = Time.at(m.time.to_f / 1000) if m.time
      d[:key] = m.key if m.key
      d[:value] = from_value m.value if m.value
      d[:host] = m.host if m.host
      d[:source] = m.source if m.source
      d[:tags] = from_tags m.tags if m.tags
      d[:attributes] = from_attributes m.attributes if m.attributes
      @core.input.metric d
      @bind.increment :received_metrics
    rescue => e
      @log.error "Failed to receive event", e
      @bind.increment :failed_metrics
    end

    private

    def from_value value
      case value.type
        when P::Value::Type::SINT64
          return value.value_sint64
        when P::Value::Type::DOUBLE
          return value.value_d
        when P::Value::Type::FLOAT
          return value.value_f
        else
          raise "No value set: #{value}"
      end
    end

    def from_attributes attributes
      Hash[attributes.map{|a| [a.key, a.value]}]
    end

    def from_tags tags
      Array.new tags
    end
  end

  DEFAULT_HOST = "localhost"
  DEFAULT_PORT = 19091
  DEFAULT_PROTOCOL = 'tcp'

  OUTPUTS = {:tcp => Output, :udp => Output}
  INPUTS = {:tcp => Input, :udp => Input}

  def self.setup_output opts, core
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT

    protocol = FFWD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)

    unless type = OUTPUTS[protocol.family]
      raise "No type for protocol family: #{protocol.family}"
    end

    protocol.connect opts, core, log, type
  end

  def self.setup_input opts, core
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT
    protocol = FFWD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)

    unless connection = INPUTS[protocol.family]
      raise "No connection for protocol family: #{protocol.family}"
    end

    protocol.bind opts, core, log, connection, log
  end

  def self.setup_tunnel opts, core, tunnel
    opts[:port] ||= DEFAULT_PORT
    protocol = FFWD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)

    unless connection = INPUTS[protocol.family]
      raise "No connection for protocol family: #{protocol.family}"
    end

    protocol.tunnel opts, core, tunnel, log, connection, log
  end
end
