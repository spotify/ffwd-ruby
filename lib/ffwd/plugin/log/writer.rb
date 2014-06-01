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

require_relative '../../logging'

module FFWD::Plugin::Log
  class Writer
    include FFWD::Logging

    def initialize core, prefix
      @p = prefix ? "#{prefix} " : ""

      subs = []

      core.output.starting do
        log.info "Started (prefix: '#{@p}')"

        subs << core.output.event_subscribe do |e|
          log.info "Event: #{@p}#{e.to_h}"
        end

        subs << core.output.metric_subscribe do |m|
          log.info "Metric: #{@p}#{m.to_h}"
        end
      end

      core.output.stopping do
        log.info "Stopped"

        subs.each(&:unsubscribe).clear
      end
    end
  end
end
