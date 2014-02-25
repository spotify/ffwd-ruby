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
require 'base64'

require_relative 'tunnel/connection_tcp'
require_relative 'tunnel/binary_protocol'

require 'ffwd/logging'
require 'ffwd/plugin'
require 'ffwd/protocol'

module FFWD::Plugin::Tunnel
  include FFWD::Plugin
  include FFWD::Logging

  register_plugin "tunnel"

  DEFAULT_HOST = 'localhost'
  DEFAULT_PORT = 9000
  DEFAULT_PROTOCOL = 'tcp'
  DEFAULT_PROTOCOL_TYPE = 'text'

  CONNECTIONS = {
    :tcp => ConnectionTCP
  }

  def self.setup_input opts, core
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT
    protocol = FFWD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)
    protocol_type = opts[:protocol_type] || DEFAULT_PROTOCOL_TYPE

    unless connection = CONNECTIONS[protocol.family]
      raise "No connection for protocol family: #{protocol.family}"
    end

    if core.tunnel_plugins.empty?
      raise "Nothing requires tunneling"
    end

    protocol.bind opts, core, log, connection, BinaryProtocol
  end
end
