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

module FFWD::Reporter
  class MissingReporterKey < Exception
  end

  def self.map_meta meta
    Hash[meta.map{|k, v| [k.to_s, v]}]
  end

  module ClassMethods
    def reporter_keys
      @_reporter_keys ||= [:total]
    end

    def reporter_meta
      @_reporter_meta ||= nil
    end

    def reporter_first
      @_reporter_first ||= nil
    end

    def reporter_meta_method
      @_reporter_meta_method ||= :reporter_meta
    end

    def setup_reporter opts={}
      @_reporter_keys = [:total] + (opts[:keys] || [])
      @_reporter_meta = opts[:reporter_meta]
      @_reporter_meta_method = opts[:id_method] || :reporter_meta
      @_reporter_first = Time.now
    end
  end

  def self.included mod
    mod.extend ClassMethods
  end

  def reporter_data
    @_reporter_keys ||= self.class.reporter_keys
    @_reporter_data ||= Hash[@_reporter_keys.map{|k| [k, 0]}]
  end

  def increment n, c=1
    if reporter_data[n].nil?
      raise MissingReporterKey.new(
        "No such reporter key: #{n.inspect} (not used in setup_reporter)"
      )
    end

    reporter_data[n] += c
    reporter_data[:total] += c
  end

  def report! now, interval=1
    last = @_reporter_last || self.class.reporter_first

    unless last.nil?
      diff = now - last
      time = Time.at(now.to_f - (now.to_f % interval))

      @_reporter_meta ||= FFWD::Reporter.map_meta(
        self.class.reporter_meta || send(self.class.reporter_meta_method))

      reporter_data.each do |k, v|
        value = v / diff
        yield(:time => time, :key => k, :value => value, :meta => @_reporter_meta)
        reporter_data[k] = 0
      end
    end

    @_reporter_last = now
  end
end
