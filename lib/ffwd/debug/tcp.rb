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

require_relative '../lifecycle'
require_relative '../logging'
require_relative '../retrier'

require_relative 'connection'
require_relative 'monitor_session'

module FFWD::Debug
  class TCP
    include FFWD::Logging
    include FFWD::Lifecycle

    def initialize host, port, rebind_timeout
      @clients = {}
      @sessions = {}
      @host = host
      @port = port
      @peer = "#{@host}:#{@port}"

      r = FFWD.retry :timeout => rebind_timeout do |attempt|
        EM.start_server @host, @port, Connection, self
        log.info "Bind on tcp://#{@peer} (attempt #{attempt})"
      end

      r.error do |a, t, e|
        log.error "Failed to bind tcp://#{@peer} (attempt #{a}), retry in #{t}s", e
      end

      r.depend_on self
    end

    def register_client peer, client
      @sessions.each do |id, session|
        session.register peer, client
      end

      @clients[peer] = client
    end

    def unregister_client peer, client
      @sessions.each do |id, session|
        session.unregister peer, client
      end

      @clients.delete peer
    end

    # Setup monitor hooks for the specified input and output channel.
    def monitor id, channel, type
      if session = @sessions[id]
        log.error "Session already monitored: #{id}"
        return
      end

      session = @sessions[id] = MonitorSession.new id, channel, type

      # provide the session to the already connected clients.
      @clients.each do |peer, client|
        session.register peer, client
      end

      channel.stopping do
        @sessions.delete id
      end
    end
  end
end
