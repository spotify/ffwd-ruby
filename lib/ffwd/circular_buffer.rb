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

Node = Struct.new(:value, :next)

module FFWD
  class CircularBuffer
    attr_reader :buffer, :capacity, :size

    def initialize capacity
      @capacity = capacity
      @first = nil
      @last = nil
      @size = 0
    end

    def clear
      @first = nil
      @last = nil
      @size = 0
    end

    def empty?
      size == 0
    end

    def peek
      return nil if @first.nil?
      @first.value
    end

    def shift
      return nil if @first.nil?
      value = @first.value
      @first = @first.next
      @last = nil if @first.nil?
      @size -= 1
      value
    end

    def << item
      node = Node.new(item, nil)

      if @last.nil?
        @first = @last = node
      else
        @last = @last.next = node
      end

      if @size >= @capacity
        @first = @first.next
      else
        @size += 1
      end
    end

    def each
      current = @first

      while not current.nil?
        yield current.value
        current = current.next
      end
    end
  end
end
