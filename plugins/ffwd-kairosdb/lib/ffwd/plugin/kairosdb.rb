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

require 'eventmachine'
require 'em-http'

require 'ffwd/logging'
require 'ffwd/plugin'
require 'ffwd/reporter'

require_relative 'kairosdb/output'

module FFWD::Plugin::KairosDB
  include FFWD::Plugin
  include FFWD::Logging

  register_plugin "kairosdb"

  DEFAULT_URL = "http://localhost:8080"
  DEFAULT_FLUSH_INTERVAL = 10
  DEFAULT_BUFFER_LIMIT = 100000

  def self.setup_output opts, core
    url = opts[:url] || DEFAULT_URL
    flush_interval = opts[:flush_interval] || DEFAULT_FLUSH_INTERVAL
    buffer_limit = opts[:buffer_limit] || DEFAULT_BUFFER_LIMIT
    Output.new core, log, url, flush_interval, buffer_limit
  end
end
