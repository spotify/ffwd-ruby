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

# EventMachine extension to create a deferrable that correctly manages multiple
# deferred objects in parallel.

module EM
  class All
    include EM::Deferrable

    def initialize
      @defs = []
      @errors = []
      @results = []
      @all_ok = true
      @any_ok = false
      @done = 0
    end

    def <<(d)
      @defs << d

      index = @results.size

      @results << nil
      @errors << nil

      d.callback do |*args|
        @results[index] = args
        @any_ok = true
        check_results
      end

      d.errback do |*args|
        @errors[index] = args
        @all_ok = false
        check_results
      end
    end

    private

    def check_results
      @done += 1

      return unless @defs.size == @done

      unless @all_ok
        fail(@errors)
        return
      end

      succeed(@results)
    end
  end
end
