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

module FFWD::Plugin::GoogleCloud
  class Hook < FFWD::FlushingOutputHook
    include FFWD::Logging

    HEADER_BASE = {
      "Content-Type" => "application/json"
    }

    def initialize c
      @api_url = c[:api_url]
      @metadata_url = c[:metadata_url]
      @project_id = c[:project_id]
      @project = c[:project]
      @client_id = c[:client_id]
      @scope = c[:scope]

      @api_c = nil
      @metadata_c = nil
      @token = nil
      @expires_at = nil
      # list of blocks waiting for a token.
      @pending = []

      @api = "/cloudmonitoring/v2beta2/projects/#{@project_id}/timeseries:write"
      @acquire = "/0.1/meta-data/service-accounts/default/acquire"
      @expire_threshold = 10
    end

    def with_token &block
      # join a pending call
      unless @pending.empty?
        proxy = CallbackProxy.new
        @pending << [block, proxy]
        return proxy
      end

      # cached, valid token
      if @token and Time.now + @expire_threshold < @expires_at
        return block.call(@token)
      end

      current_p = CallbackProxy.new
      @pending << [block, current_p]

      log.debug "Requesting token"

      http = @metadata_c.get(
        :path => @acquire,
        :query => {:client_id => @client_id, :scope => @scope})

      token_p = new_proxy(http)

      token_p.errback do
        @pending.each do |b, block_p|
          block_p.err "Token request failed: #{token_p.error}"
        end.clear
      end

      token_p.callback do
        result = JSON.load(http.response)

        @token = result['accessToken']
        @expires_at = Time.at(result['expiresAt'])

        log.debug "Got token: #{@token} (expires_at: #{@expires_at}}"

        @pending.each do |b, block_p|
          b.call(@token).into block_p
        end.clear
      end

      return current_p
    end

    def active?
      not @api_c.nil? and not @metadata_c.nil?
    end

    def connect
      @metadata_c = EM::HttpRequest.new(@metadata_url)
      @api_c = EM::HttpRequest.new(@api_url)
    end

    def close
      @metadata_c.close if @metadata_c
      @api_c.close if @api_c

      @metadata_c = nil
      @api_c = nil
    end

    def send metrics
      request = {
        "timeseries" => Utils.make_timeseries(metrics)
      }

      metrics = JSON.dump(request)

      with_token do |token|
        head = Hash[HEADER_BASE]
        head['Authorization'] = "Bearer #{token}"

        if log.debug?
          log.debug "Sending: #{metrics}"
        end

        new_proxy @api_c.post(:path => @api, :head => head, :body => metrics)
      end
    end

    # Setup a new proxy object for http request.
    # This makes sure that the callback/errback/error api as is expected by
    # flushing_output to be consistent.
    def new_proxy http
      bind_proxy http, CallbackProxy.new
    end

    def bind_proxy http, p
      http.errback do
        p.err "#{http.error}"
      end

      http.callback do
        if http.response_header.status == 200
          p.call
        else
          p.err "#{http.response_header.status}: #{http.response}"
        end
      end

      p
    end

    def reporter_meta
      {:component => :google_cloud}
    end
  end

  class CallbackProxy
    attr_reader :error

    def initialize
      @callbacks = []
      @errbacks = []
    end

    def callback &block
      @callbacks << block
    end

    def errback &block
      @errbacks << block
    end

    def call
      @callbacks.each(&:call).clear
    end

    def err error
      return if @errbacks.empty?
      @error = error
      @errbacks.each(&:call).clear
    end

    def into other
      errback { other.err error }
      callback { other.call }
    end
  end
end
