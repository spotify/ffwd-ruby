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

require 'ffwd/plugin'

module FFWD::Plugin::Kafka
  # Use a custom attribute for partitioning.
  class AttributeRouter
    DEFAULT_METRIC_PATTERN = "metrics-%s"
    DEFAULT_EVENT_PATTERN = "events-%s"
    DEFAULT_ATTRIBUTE = :site

    OPTIONS = [
      FFWD::Plugin.option(
        :metric_pattern, :default => DEFAULT_METRIC_PATTERN,
        :help => [
          "Only used with :attribute router.",
          "Metric pattern to use, expects one %s placeholder for the value of the specified attribute." 
        ]
      ),
      FFWD::Plugin.option(
        :event_pattern, :default => DEFAULT_METRIC_PATTERN,
        :help => [
          "Only used with :attribute router.",
          "Event pattern to use, expects one %s placeholder for the value of the specified attribute." 
        ]
      ),
      FFWD::Plugin.option(
        :attribute, :default => DEFAULT_ATTRIBUTE,
        :help => [
          "Only used with :attribute router.",
          "Attribute name to use in pattern when router is :attribute." 
        ]
      ),
    ]

    def self.prepare config
      config[:metric_pattern] ||= DEFAULT_METRIC_PATTERN
      config[:event_pattern] ||= DEFAULT_EVENT_PATTERN
      config[:attribute] ||= DEFAULT_ATTRIBUTE
      config
    end

    def self.build config
      metric_pattern = config[:metric_pattern] || DEFAULT_METRIC_PATTERN
      event_pattern = config[:event_pattern] || DEFAULT_EVENT_PATTERN
      attr = config[:attribute] || DEFAULT_ATTRIBUTE
      new(metric_pattern, event_pattern, attr)
    end

    def initialize config
      @metric_pattern = config[:metric_pattern]
      @event_pattern = config[:event_pattern]
      @attr = config[:attribute]
      @attr_s = @attr.to_s
    end

    def value d
      if v = d.attributes[@attr]
        return v
      end

      d.attributes[@attr_s]
    end
    p
    def route_event e
      return nil unless v = value(e)
      @event_pattern % [v]
    end

    def route_metric m
      return nil unless v = value(m)
      @metric_pattern % [v]
    end
  end

  DEFAULT_ROUTER = :attribute

  def self.prepare_router config
    type = (config[:type] ||= DEFAULT_ROUTER)
    return AttributeRouter.prepare config if type == :attribute
    raise "Unsupported router type: #{type}"
  end

  def self.build_router config
    type = config[:type]
    return AttributeRouter.new config if type == :attribute
    raise "Unsupported router type: #{type}"
  end
end
