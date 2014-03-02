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

require 'ffwd/event'
require 'ffwd/logging'
require 'ffwd/metric'
require 'ffwd/plugin'

require_relative 'log/writer'

module FFWD::Plugin
  module Log
    include FFWD::Plugin
    include FFWD::Logging

    register_plugin "log",
      :description => "A simple plugin that outputs to the primary log.",
      :options => [
        FFWD::Plugin.option(:prefix, :help => [
          "Prefix for every line logged."
        ]),
      ]

    def self.setup_output opts, core
      Writer.new core, opts.prefix
    end
  end
end
