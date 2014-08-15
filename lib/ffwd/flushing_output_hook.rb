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

module FFWD
  class FlushingOutputHook
    # Establish connections.
    def connect
      raise "not implemented: connect"
    end

    # Close any open connections.
    def close
      raise "not implemented: close"
    end

    # Return true if connection is accessible, false otherwise.
    def active?
      raise "not implemented: active?"
    end

    # Send the specified batch of metrics.
    #
    # Must return a callback object with the following attributes.
    # callback - That accepts a block that will be run on successful execution.
    # errback - That accepts a block that will be run on failed execution.
    # error - If errback has been triggered, should contain the error that
    # occured.
    def send metrics
      raise "not implemented: send"
    end

    def reporter_meta
      {}
    end
  end
end
