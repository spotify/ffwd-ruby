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

require 'json'
require 'eventmachine'

require_relative 'logging'
require_relative 'event'
require_relative 'metric'
require_relative 'retrier'
require_relative 'lifecycle'

require_relative 'debug/tcp'

module FFWD::Debug
  module Input
    def self.serialize_event event
      event = Hash[event]

      if tags = event[:tags]
        event[:tags] = tags.to_a
      end

      event
    end

    def self.serialize_metric metric
      metric = Hash[metric]

      if tags = metric[:tags]
        metric[:tags] = tags.to_a
      end

      metric
    end
  end

  module Output
    def self.serialize_event event
      event.to_h
    end

    def self.serialize_metric metric
      metric.to_h
    end
  end

  DEFAULT_REBIND_TIMEOUT = 10
  DEFAULT_HOST = "localhost"
  DEFAULT_PORT = 19001

  def self.setup opts={}
    host = opts[:host] || DEFAULT_HOST
    port = opts[:port] || DEFAULT_PORT
    rebind_timeout = opts[:rebind_timeout] || DEFAULT_REBIND_TIMEOUT
    proto = FFWD.parse_protocol(opts[:protocol] || "tcp")

    if proto == FFWD::TCP
      return TCP.new host, port, rebind_timeout
    end

    throw Exception.new("Unsupported protocol '#{proto}'")
  end
end
