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

require_relative 'json_line/connection'

module FFWD::Plugin::JsonLine
  include FFWD::Plugin
  include FFWD::Logging

  register_plugin "json_line"

  DEFAULT_HOST = "localhost"
  DEFAULT_PORT = 19000

  def self.setup_input opts, core
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT
    buffer_limit = opts["buffer_limit"] || 1000
    protocol = FFWD.parse_protocol(opts[:protocol] || "tcp")
    protocol.bind opts, core, log, Connection, buffer_limit
  end

  def self.setup_tunnel opts, core, tunnel
    opts[:port] ||= DEFAULT_PORT
    buffer_limit = opts["buffer_limit"] || 1000
    protocol = FFWD.parse_protocol(opts[:protocol] || "tcp")
    protocol.tunnel opts, core, tunnel, log, Connection, buffer_limit
  end
end
