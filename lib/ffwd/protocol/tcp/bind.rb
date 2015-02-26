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

    report_meta :protocol => :tcp, :direction => :input

    report_key :failed_events, :meta => {:what => "failed-events", :unit => :event}
    report_key :received_events, :meta => {:what => "received-events", :unit => :event}

    report_key :failed_metrics, :meta => {:what => :failed_metrics, :unit => :metric}
    report_key :received_metrics, :meta => {:what => :received_metrics, :unit => :metric}

    attr_reader :log, :reporter_meta

    def initialize core, log, host, port, connection, config
      @log = log
      @peer = "#{host}:#{port}"
      @reporter_meta = {:component => connection.plugin_type, :listen => @peer}

      @server = nil

      info = "tcp://#{@peer}"
      rebind_timeout = config[:rebind_timeout]

      r = FFWD.retry :timeout => rebind_timeout do |a|
        @server = EM.start_server host, port, connection, self, core, config

        log.info "Bind on #{info} (attempt #{a})"
        log.info "  config: #{config.inspect}"
      end

      r.error do |a, t, e|
        log.warning "Bind on #{info} failed, retry ##{a} in #{t}s: #{e}"
      end

      r.depend_on core

      core.stopping do
        if @server
          EM.stop_server @server
          @server = nil
        end

        log.info "Unbound #{info}"
      end
    end
  end
end
