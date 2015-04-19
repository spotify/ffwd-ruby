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
require 'time'

require_relative 'utils'

require 'ffwd/flushing_output_hook'

module FFWD::Plugin::Elastic
  class Hook < FFWD::FlushingOutputHook
    HEADER = {
        :'Content-Type' => 'application/json'
    }

    def initialize(host, port, index)
      @client = nil
      @url = 'http://%s:%d' % [host, port]
      @index = index
    end

    def active?
      not @client.nil?
    end

    def connect
      @client = EM::HttpRequest.new(@url)

      body = Utils.make_template_body(@index)

      body = JSON.dump(body)

      @client.post(
          :path => '/_template/template_%s' % [@index],
          :head => HEADER,
          :body => body)
    end

    def close
      @client.close
      @client = nil
    end

    def send metrics
      body = Utils.make_bulk_body(metrics)

      body = body.map { |row| JSON.dump(row) }
      body = body.join("\n")

      index = '%s-%s' % [@index, Time.now.strftime('%Y.%m.%d')]

      @client.post(
          :path => '/%s/metric/_bulk' % [index],
          :head => HEADER,
          :body => body)
    end

    def reporter_meta
      {:component => :elastic}
    end
  end
end
