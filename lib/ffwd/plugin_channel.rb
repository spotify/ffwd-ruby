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

require_relative 'lifecycle'
require_relative 'logging'
require_relative 'reporter'

module FFWD
  # A set of channels, one for metrics and one for events.
  # This is simply a convenience class to group the channel that are available
  # to a plugin in one direction (usually either input or output).
  class PluginChannel
    include FFWD::Lifecycle
    include FFWD::Reporter
    include FFWD::Logging

    setup_reporter :keys => [:metrics, :events]

    attr_reader :reporter_meta, :events, :metrics, :name

    def self.build name
      events = FFWD::Channel.new log, "#{name}.events"
      metrics = FFWD::Channel.new log, "#{name}.metrics"
      new name, metrics, events
    end

    def initialize name, events, metrics
      @name = name
      @events = events
      @metrics = metrics
      @reporter_meta = {:plugin_channel => @name, :type => "plugin_channel"}
    end

    def event_subscribe &block
      @events.subscribe(&block)
    end

    def event event
      @events << event
      increment :events
    end

    def metric_subscribe &block
      @metrics.subscribe(&block)
    end

    def metric metric
      @metrics << metric
      increment :metrics
    end
  end
end
