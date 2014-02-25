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

require 'beefcake'

require 'riemann/query'
require 'riemann/attribute'
require 'riemann/state'
require 'riemann/event'
require 'riemann/message'

module FFWD::Plugin::Riemann
  MAPPING = [
    [:key, :service, :service=],
    [:value, :metric, :metric=],
    [:host, :host, :host=],
  ]

  METRIC_MAPPING = MAPPING

  EVENT_MAPPING = [
    [:state, :state, :state=],
    [:description, :description, :description=],
    [:ttl, :ttl, :ttl=],
  ] + MAPPING

  module Shared
    def read_attributes e, source
      return if source.nil? or source.empty?

      attributes = {}

      source.each do |a|
        attributes[a.key] = a.value
      end

      e[:attributes] = attributes
    end

    def write_attributes e, source
      return if source.nil? or source.empty?

      e.attributes = source.map{|k, v|
        k = k.to_s.dup unless k.nil?
        v = v.dup unless v.nil?
        ::Riemann::Attribute.new(:key => k, :value => v)
      }
    end

    def read_tags e, source
      return if source.nil? or source.empty?
      e[:tags] = source.to_a
    end

    def write_tags e, source
      return if source.nil? or source.empty?
      e.tags = source.map{|v| v.dup}
    end

    def read_time e, source
      return if source.nil?
      e[:time] = Time.at source
    end

    def write_time e, source
      return if source.nil?
      e.time = source.to_i
    end

    def make_event event
      e = ::Riemann::Event.new

      write_attributes e, event.attributes
      write_tags e, event.tags
      write_time e, event.time

      EVENT_MAPPING.each do |key, reader, writer|
        if (v = event.send(key)).nil?
          next
        end

        v = v.to_s if v.is_a? Symbol
        e.send writer, v
      end

      e
    end

    def make_metric metric
      e = ::Riemann::Event.new

      write_attributes e, metric.attributes
      write_tags e, metric.tags
      write_time e, metric.time

      METRIC_MAPPING.each do |key, reader, writer|
        if (v = metric.send(key)).nil?
          next
        end

        v = v.to_s if v.is_a? Symbol
        e.send writer, v
      end

      e
    end

    def read_event event
      e = {}

      read_attributes e, event.attributes
      read_tags e, event.tags
      read_time e, event.time

      EVENT_MAPPING.each do |key, reader, writer|
        if (v = event.send(reader)).nil?
          next
        end

        e[key] = v
      end

      e
    end

    def make_message(message)
      ::Riemann::Message.new(message)
    end

    def read_message(data)
      ::Riemann::Message.decode data
    end
  end
end
