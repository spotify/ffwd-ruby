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

require_relative '../utils'
require_relative '../tunnel/udp'

require_relative 'udp/connect'
require_relative 'udp/bind'

module FFWD::UDP
  def self.family
    :udp
  end

  DEFAULT_REBIND_TIMEOUT = 10

  def self.connect opts, core, log, handler
    raise "Missing required key :host" if (host = opts[:host]).nil?
    raise "Missing required key :port" if (port = opts[:port]).nil?
    ignored = (opts[:ignored] || []).map{|v| Utils.check_ignored v}
    Connect.new core, log, ignored, host, port, handler
  end

  def self.bind opts, core, log, connection, *args
    raise "Missing required key :host" if (host = opts[:host]).nil?
    raise "Missing required key :port" if (port = opts[:port]).nil?
    rebind_timeout = opts[:rebind_timeout] || DEFAULT_REBIND_TIMEOUT
    Bind.new core, log, host, port, connection, args, rebind_timeout
  end

  def self.tunnel opts, core, plugin, log, connection, *args
    raise "Missing required key :port" if (port = opts[:port]).nil?
    FFWD::Tunnel::UDP.new port, core, plugin, log, connection, args
  end
end
