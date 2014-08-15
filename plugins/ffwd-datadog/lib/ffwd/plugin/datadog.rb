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

require_relative 'datadog/output'

module FFWD::Plugin::Datadog
  include FFWD::Plugin

  register_plugin "datadog"

  DEFAULT_URL = "https://app.datadoghq.com"
  DEFAULT_FLUSH_INTERVAL = 10
  DEFAULT_BUFFER_LIMIT = 100000

  class Setup
    attr_reader :config

    def initialize config
      @config = config
    end

    def connect core
      url = @config[:url] || DEFAULT_URL
      datadog_key = @config[:datadog_key]
      flush_interval = @config[:flush_interval] || DEFAULT_FLUSH_INTERVAL
      buffer_limit = @config[:buffer_limit] || DEFAULT_BUFFER_LIMIT
      Output.new core, url, datadog_key, flush_interval, buffer_limit
    end
  end

  def self.setup_output config
    Setup.new config
  end
end
