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

module FFWD::Plugin::Datadog
  module Utils
    # groups similar metadata and escapes them using the suite of safe_*
    # functions available.
    #
    # Should prevent unecessary invocations of safe_entry by only adding new
    # groups of the source metric differs (||=).
    def self.make_metrics buffer
      groups = {}

      buffer.each do |m|
        entry = {:host => m.host, :name => m.key, :attributes => m.attributes}
        group = (groups[entry] ||= safe_entry(entry).merge(:points => []))
        group[:points] << [m.time.to_i, m.value]
      end

      return {:series => groups.values}
    end

    # make safe entry out of available information.
    def self.safe_entry entry
      host = entry[:host]
      metric = entry[:name]
      tags = entry[:attributes]
      {:host => host, :metric => safe_string(metric), :tags => safe_tags(tags)}
    end

    def self.safe_string string
      string = string.to_s
      string = string.gsub " ", "_"
      string.gsub ":", "_"
    end

    def self.safe_tags tags
      safe = []

      tags.each do |key, value|
        safe_key = safe_string(key)
        safe_value = safe_string(value)
        safe << "#{safe_key}:#{safe_value}"
      end

      return safe
    end

  end
end
