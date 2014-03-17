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
require_relative 'metric'

module FFWD
  # Used to emit metrics to an 'output' channel
  #
  # Can take two parts of a configuration 'base' and 'opts' to decide which
  # metadata emitted metrics should be decorated with.
  class MetricEmitter
    def self.build output, base, opts
      host = opts[:host] || base[:host] || FFWD.current_host
      tags = FFWD.merge_sets base[:tags], opts[:tags]
      attributes = FFWD.merge_hashes base[:attributes], opts[:attributes]
      new output, host, tags, attributes
    end

    def initialize output, host, tags, attributes
      @output = output
      @host = host
      @tags = tags
      @attributes = attributes
    end

    def emit m
      m[:time] ||= Time.now
      m[:host] ||= @host if @host
      m[:tags] = FFWD.merge_sets @tags, m[:tags]
      m[:attributes] = FFWD.merge_hashes @attributes, m[:attributes]
      m[:value] = nil if m[:value] == Float::NAN

      @output.metric Metric.make(m)
    rescue => e
      log.error "Failed to emit metric", e
    end
  end
end
