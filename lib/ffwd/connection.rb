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

module FFWD
  # Connections are used by input plugins in the protocol stack.
  #
  # The sole purpose this exists is to incorporate a datasink functionality
  # in the EM::Connection.
  #
  # The datasink is used by tunnels to 'hook into' outgoing data.
  class Connection < EM::Connection
    def datasink= sink
      @datasink = sink
    end

    # send_data indirection.
    def send_data data
      if @datasink
        @datasink.send_data data
        return
      end

      super data
    end
  end
end
