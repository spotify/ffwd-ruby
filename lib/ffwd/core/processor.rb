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

require_relative '../event_emitter'
require_relative '../lifecycle'

module FFWD
  class Core; end

  # Component responsible for receiving and internally route metrics and
  # events.
  #
  # The term 'processor' is used because depending on the set of provided
  # processors it might be determined that the received metric should be
  # provided to one of them instead.
  #
  # If no processor matches, it is just passed straight through.
  class Core::Processor
    def self.build input, emitter, processors
      processors = Hash[processors.map{|p| [p.name, p.setup(emitter)]}]
      reporters = processors.select{|k, p| FFWD.is_reporter?(p)}.map{|k, p| p}
      new(input, emitter, processors, reporters)
    end

    def initialize input, emitter, processors, reporters
      @emitter = emitter
      @processors = processors
      @reporters = reporters
      @subs = []

      @processors.each do |name, p|
        p.depend_on input
      end

      input.starting do
        @subs << input.metric_subscribe do |m|
          process_metric m
        end

        @subs << input.event_subscribe do |e|
          process_event e
        end
      end

      input.stopping do
        @subs.each(&:unsubscribe).clear
      end
    end

    def report!
      @reporters.each do |reporter|
        reporter.report! do |d|
          yield d
        end
      end
    end

    private

    def process_metric m
      m[:time] ||= Time.now

      unless p = m[:proc]
        return @emitter.metric.emit m
      end

      unless p = @processors[p]
        return @emitter.metric.emit m
      end

      p.process m
    end

    def process_event e
      e[:time] ||= Time.now
      @emitter.event.emit e
    end
  end
end
