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

require 'socket'
require 'set'

module FFWD
  # Merge two sets (arrays actually)
  def self.merge_sets(a, b)
    return Set.new(a + b).to_a if a and b
    a || b || []
  end

  # Merge two hashes.
  def self.merge_hashes(a, b)
    return a.merge(b) if a and b
    b || a || {}
  end

  def self.is_reporter? var
    var.respond_to? :report!
  end

  def self.current_host
    Socket.gethostname
  end

  def self.timing &block
    start = Time.now
    block.call
    stop = Time.now
    ((stop - start) * 1000).round(3)
  end
end
