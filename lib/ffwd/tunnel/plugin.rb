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

# describes the protocol that has to be implemented by a tunnel.

module FFWD::Tunnel
  class Plugin
    # Object type that should be returned by 'tcp'.
    class Handle
      def close &block
        raise "Not implemented: close"
      end

      def data &block
        raise "Not implemented: data"
      end

      def send_data data
        raise "Not implemented: send_data"
      end
    end

    def tcp port, &block
      raise "Not implemented: tcp"
    end

    def udp port, &block
      raise "Not implemented: udp"
    end

    def send_data addr, data
      raise "Not implemented: send_data"
    end
  end
end
