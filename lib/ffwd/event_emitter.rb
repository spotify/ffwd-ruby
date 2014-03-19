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

require_relative 'utils'
require_relative 'event'
require_relative 'logging'

module FFWD
  # Used to emit events to an 'output' channel
  #
  # Can take two parts of a configuration 'base' and 'opts' to decide which
  # metadata emitted events should be decorated with.
  class EventEmitter
    include FFWD::Logging

    def self.build output, base, opts
      output = output
      host = opts[:host] || base[:host] || FFWD.current_host
      ttl = opts[:ttl] || base[:ttl]
      tags = FFWD.merge_sets base[:tags], opts[:tags]
      attributes = FFWD.merge_hashes base[:attributes], opts[:attributes]
      new output, host, ttl, tags, attributes
    end

    def initialize output, host, ttl, tags, attributes
      @output = output
      @host = host
      @ttl = ttl
      @tags = tags
      @attributes = attributes
    end

    def emit e
      e[:time] ||= Time.now
      e[:host] ||= @host if @host
      e[:ttl] ||= @ttl if @ttl
      e[:tags] = FFWD.merge_sets @tags, e[:tags]
      e[:attributes] = FFWD.merge_hashes @attributes, e[:attributes]
      e[:value] = nil if (v = e[:value] and v.is_a?(Float) and v.nan?)

      @output.event Event.make(e)
    rescue => e
      log.error "Failed to emit event", e
    end
  end
end
