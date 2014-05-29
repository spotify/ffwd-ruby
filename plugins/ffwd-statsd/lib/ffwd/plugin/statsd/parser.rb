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

module FFWD::Plugin::Statsd
  class ParserError < Exception; end

  module Parser
    COUNT = "count"
    HISTOGRAM = "histogram"
    RATE = "rate"

    def self.gauge name, value
      {:proc => nil, :key => name, :value => value}
    end

    def self.count name, value
      {:proc => COUNT, :key => name, :value => value}
    end

    def self.meter name, value
      {:proc => RATE, :key => name, :value => value}
    end

    def self.timing name, value
      {:proc => HISTOGRAM, :key => name, :value => value}
    end

    def self.parse m
      name, value = m.split ':', 2

      if value.nil?
        raise ParserError.new("Missing value")
      end

      value, type_block = value.split '|', 2

      if type_block.nil?
        raise ParserError.new("Missing type")
      end

      type, sample_rate = type_block.split '|@', 2

      if type.nil? or type.empty?
        raise ParserError.new("Missing type")
      end

      if value.nil? or value.empty?
        raise ParserError.new("Missing value")
      end

      value = value.to_f

      sample_rate = sample_rate.to_f unless sample_rate.nil?

      value /= sample_rate unless sample_rate.nil?

      if type == "g"
        return gauge(name, value)
      end

      if type == "c"
        return count(name, value)
      end

      if type == "m"
        return meter(name, value)
      end

      if type == "ms" or type == "h"
        return timing(name, value)
      end

      raise ParserError.new(
        "Received message of unsupported type '#{type}'")
    end
  end
end
