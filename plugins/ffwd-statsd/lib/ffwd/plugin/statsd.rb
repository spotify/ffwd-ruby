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
require 'ffwd/protocol'
require 'ffwd/logging'

require_relative 'statsd/connection'

module FFWD::Plugin::Statsd
  include FFWD::Plugin
  include FFWD::Logging

  register_plugin "statsd"

  DEFAULT_HOST = "localhost"
  DEFAULT_PORT = 8125
  DEFAULT_PROTOCOL = "udp"

  class InputUDP < FFWD::Plugin::Statsd::Connection
    def self.plugin_type
      "statsd_udp_in"
    end

    def receive_data data
      receive_statsd_frame data
    end
  end

  class InputTCP < FFWD::Plugin::Statsd::Connection
    include EM::Protocols::LineText2

    def self.plugin_type
      "statsd_tcp_in"
    end

    def receive_line(data)
      receive_statsd_frame data
    end
  end

  INPUTS = {:tcp => InputTCP, :udp => InputUDP}

  def self.setup_input config
    config[:host] ||= DEFAULT_HOST
    config[:port] ||= DEFAULT_PORT
    config[:protocol] ||= DEFAULT_PROTOCOL

    protocol = FFWD.parse_protocol config[:protocol]

    unless connection = INPUTS[protocol.family]
      raise "No connection for protocol family: #{protocol.family}"
    end

    protocol.bind config, log, connection
  end
end
