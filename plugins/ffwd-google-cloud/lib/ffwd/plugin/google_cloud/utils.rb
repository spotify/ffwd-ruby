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
require 'set'
require 'zlib'

module FFWD::Plugin::GoogleCloud
  CUSTOM_PREFIX = "custom.cloudmonitoring.googleapis.com"

  module Utils
    M64 = 1 << 64

    def self.make_common_labels buffer
      return nil if buffer.empty?
      make_labels buffer.first.fixed_attr
    end

    def self.make_timeseries buffer
      # we are not allowed to send duplicate data.
      seen = Set.new

      result = []
      dropped = 0

      buffer.each do |m|
        d = make_desc(m)

        # using built-in hash OK since we are only internally de-duplicating.
        seen_key = [d[:metric], d[:labels].keys.sort].hash

        if seen.member?(seen_key)
          dropped += 1
          next
        end

        seen.add(seen_key)
        result << {:timeseriesDesc => d, :point => make_point(m)}
      end

      [dropped, result]
    end

    def self.make_point m
      time = m.time.utc.strftime('%FT%TZ')
      {:start => time, :end => time, :doubleValue => m.value}
    end

    def self.make_desc m
      {:metric => make_key(m), :labels => make_labels(m.external_attr)}
    end

    def self.make_key m
      attributes = Hash[m.external_attr]

      entries = []

      what ||= attributes.delete(:what)
      what ||= attributes.delete("what")

      entries << what unless what.nil?
      entries = entries.join('.')

      # ruby Object#hash is inconsistent across runs, so we will instead
      # perform a custom hashing.
      hash = hash_labels(attributes).to_s(32)

      unless entries.empty?
        "#{CUSTOM_PREFIX}/#{m.key}/#{entries}-#{hash}"
      else
        "#{CUSTOM_PREFIX}/#{m.key}-#{other_keys}"
      end
    end

    def self.hash_labels attributes
      attributes.keys.sort.map{|v| Zlib::crc32(v.to_s)}.reduce(33){|k, v|
        (63 * k + v).modulo(M64)
      }
    end

    def self.make_labels attr
      Hash[attr.select{|k, v| k.to_s != "what"}.map{|k, v|
        ["#{CUSTOM_PREFIX}/#{k}", v]
      }]
    end

    def self.extract_labels source
      source.map{|k, v| {:key => k, :description => ""}}
    end
  end
end
