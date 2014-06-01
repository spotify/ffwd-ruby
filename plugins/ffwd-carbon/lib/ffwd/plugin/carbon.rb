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

require 'ffwd/protocol'
require 'ffwd/plugin'
require 'ffwd/logging'

require_relative 'carbon/connection'

module FFWD::Plugin
  module Carbon
    include FFWD::Plugin
    include FFWD::Logging

    DEFAULT_HOST = "localhost"
    DEFAULT_PORT = 2003
    DEFAULT_PROTOCOL = "tcp"

    register_plugin "carbon",
      :description => "A plugin for the carbon line protocol.",
      :options => [
        FFWD::Plugin.option(
          :host, :default => DEFAULT_HOST, :modes => [:input],
          :help => [
            "Host to bind to."
          ]),
        FFWD::Plugin.option(
          :port, :default => DEFAULT_PORT,
          :help => [
            "Port to bind to."
          ]),
      ]

    class InputTCP < FFWD::Plugin::Carbon::Connection
      def self.plugin_type
        "carbon_tcp_in"
      end
    end

    class InputUDP < FFWD::Plugin::Carbon::Connection
      def self.plugin_type
        "carbon_udp_in"
      end
    end

    INPUTS = {:tcp => InputTCP, :udp => InputUDP}

    def self.setup_input config
      config[:host] ||= DEFAULT_HOST
      config[:port] ||= DEFAULT_PORT
      config[:protocol] ||= DEFAULT_PROTOCOL
      protocol = FFWD.parse_protocol config[:protocol]

      unless connection = INPUTS[protocol.family]
        raise "Not supported protocol: #{protocol}"
      end

      protocol.bind config, log, connection
    end
  end
end
