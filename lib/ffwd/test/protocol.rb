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

require 'ffwd/handler'
require 'ffwd/connection'

module FFWD::Test
  module Protocol
    def valid_output klass, opts={}
      expect(klass < FFWD::Handler).to be true
      sig = double
      connect = double
      config = opts[:config] || double
      expect(klass.respond_to?(:plugin_type)).to be true
      expect(klass.plugin_type.nil?).to be false
      return klass.new sig, connect, config
    end

    def valid_input klass, opts={}
      expect(klass < FFWD::Connection).to be true
      sig = double
      bind = double
      core = double
      config = opts[:config] || double
      expect(klass.respond_to?(:plugin_type)).to be true
      expect(klass.plugin_type.nil?).to be false
      return klass.new sig, bind, core, config
    end
  end
end
