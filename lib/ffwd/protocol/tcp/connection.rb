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

module FFWD::TCP
  class Connection
    INITIAL_TIMEOUT = 2

    attr_reader :log, :peer, :reporter_meta

    def initialize log, host, port, handler, args, outbound_limit
      @log = log
      @host = host
      @port = port
      @handler = handler
      @args = args
      @outbound_limit = outbound_limit

      @peer = "#{host}:#{port}"
      @closing = false
      @reconnect_timeout = INITIAL_TIMEOUT
      @reporter_meta = {:type => @handler.plugin_type, :peer => peer}

      @timer = nil
      @c = nil
      @open = false
    end

    # Start attempting to connect.
    def connect
      log.info "Connecting to tcp://#{@host}:#{@port}"
      @c = EM.connect @host, @port, @handler, self, *@args
    end

    # Explicitly disconnect and discard any reconnect attempts..
    def disconnect
      log.info "Disconnecting from tcp://#{@host}:#{@port}"
      @closing = true

      @c.close_connection if @c
      @timer.cancel if @timer
      @c = nil
      @timer = nil
    end

    def send_event event
      @c.send_event event
    end

    def send_metric metric
      @c.send_metric metric
    end

    def send_all events, metrics
      @c.send_all events, metrics
    end

    def connection_completed
      @open = true
      @log.info "Connected tcp://#{peer}"
      @reconnect_timeout = INITIAL_TIMEOUT

      unless @timer.nil?
        @timer.cancel
        @timer = nil
      end
    end

    def unbind
      @open = false
      @c = nil

      if @closing
        return
      end

      @log.info "Disconnected from tcp://#{peer}, reconnecting in #{@reconnect_timeout}s"

      unless @timer.nil?
        @timer.cancel
        @timer = nil
      end

      @timer = EM::Timer.new(@reconnect_timeout) do
        @reconnect_timeout *= 2
        @timer = nil
        @c = EM.connect @host, @port, @handler, self, *@args
      end
    end

    # Check if a connection is writable or not.
    def writable?
      not @c.nil? and @open and @c.get_outbound_data_size < @outbound_limit
    end
  end
end
