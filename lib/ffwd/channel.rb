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

require 'set'

# Defines containers which are limited in size.
module FFWD
  class Channel
    class Sub
      attr_reader :channel, :block

      def initialize channel, block
        @channel = channel
        @block = block
      end

      def unsubscribe
        @channel.unsubscribe self
      end
    end

    attr_reader :subs

    def initialize log, name
      @log = log
      @name = name
      @subs = Set.new
    end

    def <<(item)
      @subs.each do |sub|
        begin
          sub.block.call item
        rescue => e
          @log.error "#{@name}: Subscription failed", e
        end
      end
    end

    def subscribe(&block)
      s = Sub.new(self, block)
      @subs << s
      return s
    end

    def unsubscribe sub
      @subs.delete sub
    end
  end
end
