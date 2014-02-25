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

require_relative '../schema'

require 'json'

module FFWD::Schema
  # Spotify's metric schema.
  module Spotify100
    include FFWD::Schema

    VERSION = "1.0.0"

    module ApplicationJSON
      def self.dump_metric m
        d = {}
        d[:version] = VERSION
        d[:time] = (m.time.to_f * 1000).to_i if m.time
        d[:key] = m.key if m.key
        d[:value] = m.value if m.value
        d[:host] = m.host if m.host
        d[:tags] = m.tags.to_a if m.tags
        d[:attributes] = m.attributes if m.attributes
        JSON.dump d
      end

      def self.dump_event e
        d = {}
        d[:version] = VERSION
        d[:time] = (e.time.to_f * 1000).to_i if e.time
        d[:key] = e.key if e.key
        d[:value] = e.value if e.value
        d[:host] = e.host if e.host
        d[:state] = e.state if e.state
        d[:description] = e.description if e.description
        d[:ttl] = e.ttl if e.ttl
        d[:tags] = e.tags.to_a if e.tags
        d[:attributes] = e.attributes if e.attributes
        JSON.dump d
      end
    end

    register_schema 'spotify 1.0.0', 'application/json', ApplicationJSON
  end
end
