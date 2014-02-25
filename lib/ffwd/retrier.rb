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

require_relative 'logging'
require_relative 'lifecycle'

module FFWD
  # Try to execute a block on an exponential timer until it no longer throws
  # an exception.
  class Retrier
    include FFWD::Lifecycle

    def initialize timeout, &block
      @block = block
      @timer = nil
      @timeout = timeout
      @current_timeout = @timeout
      @attempt = 0
      @error_callbacks = []

      starting do
        try_block
      end

      stopping do
        if @timer
          @timer.cancel
          @timer = nil
        end
      end
    end

    def error &block
      @error_callbacks << block
    end

    def try_block
      @attempt += 1
      @block.call @attempt
      @current_timeout = @timeout
    rescue => e
      @error_callbacks.each do |block|
        block.call @attempt, @current_timeout, e
      end

      @timer = EM::Timer.new(@current_timeout) do
        @current_timeout *= 2
        @timer = nil
        try_block
      end
    end
  end

  DEFAULT_TIMEOUT = 10

  def self.retry opts={}, &block
    timeout = opts[:timeout] || DEFAULT_TIMEOUT
    Retrier.new(timeout, &block)
  end
end
