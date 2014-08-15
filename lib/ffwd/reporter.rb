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
  def self.map_meta meta
    Hash[meta.map{|k, v| [k.to_s, v]}]
  end

  def self.build_meta instance, k
    meta = instance.class.reporter_meta || {}

    if instance.respond_to?(:reporter_meta)
      meta = meta.merge(instance.send(:reporter_meta))
    end

    return meta.merge(k[:meta])
  end

  module ClassMethods
    def reporter_keys
      @reporter_keys ||= []
    end

    # Statically configured metadata.
    def reporter_meta
      @reporter_meta ||= {}
    end

    # Configure either static or dynamic metadata.
    # If a symbol is provided, it is assumed to be the name of the function
    # that will be used to fetch metadata.
    # If a Hash is provided, it will be assumed to be the static metadata.
    def report_meta meta
      unless meta.is_a? Hash
        raise "Invalid meta: #{meta.inspect}"
      end

      @reporter_meta = meta
    end

    def report_key key, options={}
      reporter_keys <<  {:key => key, :meta => options[:meta] || {}}
    end

    def setup_reporter opts={}
      raise "setup_reporter is deprecated, use (report_*) instead!"
    end
  end

  def self.included mod
    mod.extend ClassMethods
  end

  def reporter_data
    @_reporter_data ||= Hash[self.class.reporter_keys.map{|k| [k[:key], 0]}]
  end

  def increment n, c=1
    reporter_data[n] += c
  end

  def report!
    self.class.reporter_keys.each do |key|
      k = key[:key]
      v = reporter_data[k]
      reporter_data[k] = 0

      meta = ((@_reporter_meta ||= {})[k] ||= FFWD::Reporter.build_meta(self, key))

      yield(:key => k, :value => v, :meta => meta)
    end
  end
end
