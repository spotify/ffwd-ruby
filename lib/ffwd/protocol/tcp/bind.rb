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

require_relative '../../reporter'
require_relative '../../retrier'

module FFWD::TCP
  class Bind
    include FFWD::Reporter

    # Default initial timeout when binding fails.
    DEFAULT_REBIND_TIMEOUT = 10

    def self.prepare opts
      opts[:rebind_timeout] ||= DEFAULT_REBIND_TIMEOUT
      opts
    end

    setup_reporter :keys => [
      :received_events, :received_metrics,
      :failed_events, :failed_metrics
    ]

    attr_reader :reporter_meta

    def initialize core, log, host, port, connection, args, config
      @config = config
      @peer = "#{host}:#{port}"
      @reporter_meta = {
        :type => connection.plugin_type,
        :listen => @peer, :family => 'tcp'
      }

      @sig = nil

      info = "tcp://#{@peer}"
      rebind_timeout = config[:rebind_timeout]

      r = FFWD.retry :timeout => rebind_timeout do |a|
        @sig = EM.start_server host, port, connection, self, core, *args
        log.info "Bind on #{info} (attempt #{a})"
        log.info "  config: #{@config.inspect}"
      end

      r.error do |a, t, e|
        log.warning "Bind on #{info} failed, retry ##{a} in #{t}s: #{e}"
      end

      r.depend_on core

      core.stopping do
        log.info "Unbinding #{info}"

        if @sig
          EM.stop_server @sig
          @sig = nil
        end
      end
    end
  end
end
