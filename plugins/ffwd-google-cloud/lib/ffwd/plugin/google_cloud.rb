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
require 'ffwd/flushing_output'

require_relative 'google_cloud/hook'

module FFWD::Plugin::GoogleCloud
  include FFWD::Plugin
  include FFWD::Logging

  register_plugin "google-cloud"

  DEFAULT_API_URL = "https://www.googleapis.com"
  DEFAULT_METADATA_URL = "http://metadata.google.internal"
  DEFAULT_SCOPE = "https://www.googleapis.com/auth/monitoring"
  DEFAULT_FLUSH_INTERVAL = 10
  DEFAULT_BUFFER_LIMIT = 100
  DEFAULT_DEBUG = false

  def self.setup_output config
    if not config[:project_id]
      raise "'project_id' is required"
    end

    if not config[:project]
      raise "'project' is required"
    end

    if not config[:client_id]
      raise "'client_id' is required"
    end

    config[:scope] ||= DEFAULT_SCOPE
    config[:metadata_url] ||= DEFAULT_METADATA_URL
    config[:api_url] ||= DEFAULT_API_URL
    config[:flush_interval] ||= DEFAULT_FLUSH_INTERVAL
    config[:buffer_limit] ||= DEFAULT_BUFFER_LIMIT
    # Fake all API interaction (output with log.debug)
    config[:debug] ||= DEFAULT_DEBUG

    hook = Hook.new(config)

    FFWD.flushing_output log, hook, config
  end
end
