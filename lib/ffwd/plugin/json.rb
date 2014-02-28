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

require 'eventmachine'

require 'ffwd/protocol'
require 'ffwd/plugin'
require 'ffwd/logging'

require_relative 'json/connection'

module FFWD::Plugin::JSON
  include FFWD::Plugin
  include FFWD::Logging

  DEFAULT_HOST = "localhost"
  DEFAULT_PORT = 19000
  DEFAULT_PROTOCOL = "tcp"

  register_plugin "json",
    :description => "A simple JSON protocol implementation",
    :options => [
      FFWD::Plugin.option(
        :kind, :default => :line,
        :help => "Kind of protocol to use, valid options are: :frame and :line."),
      FFWD::Plugin.option(
        :protocol, :default => DEFAULT_PROTOCOL,
        :help => "Protocol to use when receiving messages. When :kind is :frame, this should be 'udp'.")
    ]

  class LineConnection < FFWD::Connection
    include FFWD::Logging
    include FFWD::Plugin::JSON::Connection
    include EM::Protocols::LineText2

    def self.plugin_type
      "json_line_in"
    end

    def receive_line data
      receive_json data
    end
  end

  class FrameConnection < FFWD::Connection
    include FFWD::Logging
    include FFWD::Plugin::JSON::Connection

    def self.plugin_type
      "json_frame_in"
    end

    def receive_data data
      receive_json data
    end
  end

  KINDS = {
    :frame => FrameConnection,
    :line => LineConnection,
  }

  def self.setup_input opts, core
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT
    protocol = FFWD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)
    kind = opts[:kind] || :line
    unless connection = KINDS[kind]
      raise "No such kind: #{kind}"
    end

    protocol.bind opts, core, log, connection
  end

  def self.setup_tunnel opts, core, tunnel
    opts[:port] ||= DEFAULT_PORT
    protocol = FFWD.parse_protocol(opts[:protocol] || "tcp")
    kind = opts[:kind] || :line
    unless connection = KINDS[kind]
      raise "No such kind: #{kind}"
    end

    protocol.tunnel opts, core, tunnel, log, connection
  end
end
