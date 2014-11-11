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

module FFWD::Plugin::Collectd
  # A minimal implementation of a reader for collectd's types.db
  #
  # http://collectd.org/documentation/manpages/types.db.5.shtml
  class TypesDB
    def initialize database
      @database = database
    end

    def get_name key, i
      if entry = @database[key] and spec = entry[i]
        return spec[0]
      end

      return i.to_s
    end

    def self.open path
      return nil unless File.file? path

      database = {}

      File.open(path) do |f|
        f.readlines.each do |line|
          next if line.start_with? "#"
          parts = line.split(/[\t ]+/, 2)
          next unless parts.size == 2
          key, value_specs = parts
          value_specs = value_specs.split(",").map(&:strip)
          value_specs = value_specs.map{|s| s.split(':')}
          database[key] = value_specs
        end
      end

      new database
    end
  end
end
