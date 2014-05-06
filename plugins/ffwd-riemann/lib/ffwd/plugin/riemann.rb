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
require 'beefcake'

require 'riemann/query'
require 'riemann/attribute'
require 'riemann/state'
require 'riemann/event'
require 'riemann/message'

require 'ffwd/logging'
require 'ffwd/plugin'
require 'ffwd/protocol'

require_relative 'riemann/connection'
require_relative 'riemann/shared'
require_relative 'riemann/output'

module FFWD::Plugin::Riemann
  include FFWD::Plugin
  include FFWD::Logging

  register_plugin "riemann"

  class OutputTCP < FFWD::Plugin::Riemann::Output
    def self.plugin_type
      "riemann_out"
    end

    def encode m
      m.encode_with_length
    end
  end

  class OutputUDP < FFWD::Plugin::Riemann::Output
    def self.plugin_type
      "riemann_out"
    end

    def encode m
      m.encode
    end
  end

  class InputTCP < FFWD::Plugin::Riemann::Connection
    include EM::Protocols::ObjectProtocol

    def self.plugin_type
      "riemann_in"
    end

    def send_ok
      send_object(::Riemann::Message.new(
        :ok => true))
    end

    def send_error(e)
      send_object(::Riemann::Message.new(
        :ok => false, :error => e.to_s))
    end
  end

  class InputUDP < FFWD::Plugin::Riemann::Connection
    def self.plugin_type
      "riemann_in"
    end

    def receive_data(data)
      receive_object serializer.load(data)
    end
  end

  DEFAULT_HOST = "localhost"
  DEFAULT_PORT = 5555
  DEFAULT_PROTOCOL = 'tcp'
  DEFAULT_CHUNK_SIZE = 100

  OUTPUTS = {:tcp => OutputTCP, :udp => OutputUDP}
  INPUTS = {:tcp => InputTCP, :udp => InputUDP}

  def self.setup_output opts, core
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT

    protocol = FFWD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)

    unless type = OUTPUTS[protocol.family]
      raise "No type for protocol family: #{protocol.family}"
    end

    chunk_size = opts[:chunk_size] || DEFAULT_CHUNK_SIZE

    protocol.connect opts, core, log, type, chunk_size
  end

  def self.setup_input opts, core
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT
    protocol = FFWD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)

    unless connection = INPUTS[protocol.family]
      raise "No connection for protocol family: #{protocol.family}"
    end

    protocol.bind opts, core, log, connection, log
  end

  def self.setup_tunnel opts, core, tunnel
    opts[:port] ||= DEFAULT_PORT
    protocol = FFWD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)

    unless connection = INPUTS[protocol.family]
      raise "No connection for protocol family: #{protocol.family}"
    end

    protocol.tunnel opts, core, tunnel, log, connection, log
  end
end
