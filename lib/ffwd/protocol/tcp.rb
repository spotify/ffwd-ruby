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
require_relative '../tunnel/tcp'

require_relative 'tcp/bind'
require_relative 'tcp/plain_connect'
require_relative 'tcp/flushing_connect'
require_relative 'tcp/connection'

module FFWD::TCP
  def self.family
    :tcp
  end

  # default amount of bytes that the outbound connection will allow in its
  # application-level buffer.
  DEFAULT_OUTBOUND_LIMIT = 2 ** 20
  # default flush period, if non-zero will cause the connection to be buffered.
  DEFAULT_FLUSH_PERIOD = 10
  # defaults for buffered connections.
  # maximum amount of events to buffer up.
  DEFAULT_EVENT_LIMIT = 1000
  # maximum amount of metrics to buffer up.
  DEFAULT_METRIC_LIMIT = 10000
  # percent of maximum events/metrics which will cause a flush.
  DEFAULT_FLUSH_LIMIT = 0.8
  # Default initial timeout when binding fails.
  DEFAULT_REBIND_TIMEOUT = 10

  # Establish an outbound tcp connection.
  #
  # opts - Option hash.
  #   Expects the following keys.
  #     :host - The host to connect to.
  #     :port - The port to connect to.
  #     :outbound_limit - The amount of bytes that are allowed to be pending in
  #     the application level buffer for the connection to be considered
  #     'writable'.
  #     :flush_period - The period in which outgoing data is buffered. If this
  #     is 0 no buffering will occur.
  #   Reads the following keys if the connection is buffered.
  #     :event_limit - The maximum amount of events the connection is allowed
  #     to buffer up.
  #     :metric_limimt - The maximum amount of metrics the connection is
  #     allowed to buffer up.
  #     :flush_limit - A percentage (0.0 - 1.0) indicating 'the percentage of
  #     events/metrics' that is required for a flush to be forced.
  #     If this percentage is reached, the connection will attempt to forcibly
  #     flush all buffered events and metrics prior to the end of the flushing
  #     period.
  # core - The core interface associated with this connection.
  # log - The logger to use for this connection.
  # handler - An implementation of FFWD::Handler containing the connection
  # logic.
  # args - Arguments passed to the handler when a new instance is created.
  def self.connect opts, core, log, handler, *args
    raise "Missing required option :host" if (host = opts[:host]).nil?
    raise "Missing required option :port" if (port = opts[:port]).nil?

    outbound_limit = opts[:outbound_limit] || DEFAULT_OUTBOUND_LIMIT
    flush_period = opts[:flush_period] || DEFAULT_FLUSH_PERIOD
    ignored = (opts[:ignored] || []).map{|v| Utils.check_ignored v}

    connection = Connection.new log, host, port, handler, args, outbound_limit

    if flush_period == 0
      PlainConnect.new core, log, ignored, connection
    else
      event_limit = opts[:event_limit] || DEFAULT_EVENT_LIMIT
      metric_limit = opts[:metric_limit] || DEFAULT_METRIC_LIMIT
      flush_limit = opts[:flush_limit] || DEFAULT_FLUSH_LIMIT

      FlushingConnect.new(
        core, log, ignored, connection,
        flush_period, event_limit, metric_limit, flush_limit
      )
    end
  end

  # Bind and listen for a TCP connection.
  #
  # opts - Option hash.
  #   :host - The host to bind to.
  #   :port - The port to bind to.
  #   :rebind_timeout - The initial timeout to use when rebinding the
  #   connection.
  # core - The core interface associated with this connection.
  # log - The logger to use for this connection.
  # connection - An implementation of FFWD::Connection containing the
  # connection logic.
  # args - Arguments passed to the connection when a new instance is created.
  def self.bind opts, core, log, connection, *args
    raise "Missing required option :host" if (host = opts[:host]).nil?
    raise "Missing required option :port" if (port = opts[:port]).nil?
    rebind_timeout = opts[:rebind_timeout] || DEFAULT_REBIND_TIMEOUT
    Bind.new core, log, host, port, connection, args, rebind_timeout
  end

  # Set up a TCP tunnel.
  #
  # opts - Option hash.
  #   :port - The port to bind to on the remote side.
  # core - The core interface associated with this connection.
  # log - The logger to use for this connection.
  # connection - An implementation of FFWD::Connection containing the
  # connection logic.
  # args - Arguments passed to the connection when a new instance is created.
  def self.tunnel opts, core, plugin, log, connection, *args
    raise "Missing required option :port" if (port = opts[:port]).nil?
    FFWD::Tunnel::TCP.new port, core, plugin, log, connection, args
  end
end
