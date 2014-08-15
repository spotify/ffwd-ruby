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

require 'json'

require_relative 'utils'

require 'ffwd/flushing_output_hook'

module FFWD::Plugin::Datadog
  class Hook < FFWD::FlushingOutputHook
    HEADER = {
      "Content-Type" => "application/json"
    }

    API_PATH = "/api/v1/series"

    def initialize url, datadog_key
      @c = nil
      @url = url
      @datadog_key = datadog_key
    end

    def active?
      not @c.nil?
    end

    def connect
      @c = EM::HttpRequest.new(@url)
    end

    def close
      @c.close
      @c = nil
    end

    def send metrics
      metrics = Utils.make_metrics(metrics)
      metrics = JSON.dump(metrics)

      @c.post(:path => API_PATH,
              :query => {'api_key' => @datadog_key },
              :head => HEADER,
              :body => metrics)
    end

    def reporter_meta
      {:component => :datadog}
    end
  end
end
