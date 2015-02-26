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

module FFWD::Plugin::GoogleCloud
  module Utils
    def self.make_timeseries buffer
      buffer.map do |m|
        {:timeseriesDesc => make_desc(m), :point => make_point(m)}
      end
    end

    def self.make_point m
      time = m.time.utc.strftime('%FT%TZ')
      {:start => time, :end => time, :doubleValue => m.value}
    end

    def self.make_desc m
      {:metric => m.key, :labels => make_labels(m)}
    end

    def self.make_labels m
      labels = Hash[m.attributes]
      labels["host"] = m.host
      labels
    end
  end
end
