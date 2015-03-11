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

module FFWD::Plugin::GoogleCloud
  CUSTOM_PREFIX = "custom.cloudmonitoring.googleapis.com"

  module Utils
    def self.make_timeseries buffer
      # we are not allowed to send duplicate data.
      seen = Set.new

      result = []
      dropped = 0

      buffer.each do |m|
        d = make_desc(m)

        if seen.member?(d[:metric])
          dropped += 1
          next
        end

        seen.add(d[:metric])
        result << {:timeseriesDesc => d, :point => make_point(m)}
      end

      [dropped, result]
    end

    def self.make_point m
      time = m.time.utc.strftime('%FT%TZ')
      {:start => time, :end => time, :doubleValue => m.value}
    end

    def self.make_desc m
      {:metric => make_key(m), :labels => make_labels(m)}
    end

    def self.make_key m
      attributes = Hash[m.attributes]

      entries = []

      what ||= attributes.delete(:what)
      what ||= attributes.delete("what")

      entries << what unless what.nil?
      entries += attributes.keys.sort.map(&:to_s)
      entries = entries.join('.')

      unless entries.empty?
        "#{CUSTOM_PREFIX}/#{m.key}/#{entries}"
      else
        "#{CUSTOM_PREFIX}/#{m.key}"
      end
    end

    def self.make_labels m
      labels = Hash[m.attributes.select{|k, v| k.to_s != "what"}.map{|k, v|
        ["#{CUSTOM_PREFIX}/#{k}", v]
      }]

      #labels["#{CUSTOM_PREFIX}/host"] = m.host
      labels
    end

    def self.extract_labels source
      source.map{|k, v| {:key => k, :description => k}}
    end
  end
end
