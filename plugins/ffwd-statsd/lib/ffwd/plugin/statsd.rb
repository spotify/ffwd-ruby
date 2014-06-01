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

  INPUTS = {:tcp => Connection::TCP, :udp => Connection::UDP}

  def self.setup_input opts
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT
    protocol = FFWD.parse_protocol(opts[:protocol] || "udp")

    unless connection = INPUTS[protocol.family]
      raise "No connection for protocol family: #{protocol.family}"
    end

    protocol.bind opts, log, connection
  end
end
