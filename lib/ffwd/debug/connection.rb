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

module FFWD::Debug
  class Connection < EM::Connection
    include FFWD::Logging

    def initialize handler
      @handler = handler
      @peer = nil
      @ip = nil
      @port = nil
    end

    def get_peer
      peer = get_peername
      port, ip = Socket.unpack_sockaddr_in(peer)
      return peer, ip, port
    end

    def post_init
      @peer, @ip, @port = get_peer
      @handler.register_client @peer, self
      log.info "#{@ip}:#{@port}: Connect"
    end

    def unbind
      @handler.unregister_client @peer, self
      log.info "#{@ip}:#{@port}: Disconnect"
    end

    def send_line line
      send_data "#{line}\n"
    end
  end
end
