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

module FFWD::Plugin::KairosDB
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
        group = (groups[entry] ||= safe_entry(entry).merge(:datapoints => []))
        group[:datapoints] << [(m.time.to_f * 1000).to_i, m.value]
      end

      return groups.values
    end

    # make safe entry out of available information.
    def self.safe_entry entry
      name = entry[:name]
      host = entry[:host]
      attributes = entry[:attributes]
      {:name => safe_string(name), :tags => safe_tags(host, attributes)}
    end

    # Warning: These are the 'bad' characters I've been able to reverse
    # engineer so far.
    def self.safe_string string
      string = string.to_s
      string = string.gsub " ", "/"
      string.gsub ":", "_"
    end

    # Warning: KairosDB ignores complete metrics if you use tags which have no
    # values, therefore I have not figured out a way to transport 'tags'.
    def self.safe_tags host, attributes
      tags = {"host" => safe_string(host)}

      attributes.each do |key, value|
        tags[safe_string(key)] = safe_string(value)
      end

      return tags
    end

  end
end
