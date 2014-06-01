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

require_relative '../../reporter'
require_relative '../../retrier'

module FFWD::UDP
  class Connect
    include FFWD::Reporter

    RESOLVE_TIMEOUT = 10

    def self.prepare config
      config[:ignored] = (config[:ignored] || []).map{|v| Utils.check_ignored v}
      config
    end

    attr_reader :reporter_meta, :log, :config

    setup_reporter :keys => [
      :dropped_events, :dropped_metrics,
      :sent_events, :sent_metrics
    ]

    def initialize core, log, host, port, handler, config
      @log = log
      @host = host
      @port = port
      @handler = handler

      ignored = config[:ignored]

      @bind_host = "0.0.0.0"
      @host_ip = nil
      @c = nil
      @peer = "#{host}:#{port}"
      @reporter_meta = {
        :type => @handler.plugin_type, :peer => @peer
      }

      info = "udp://#{@peer}"

      @subs = []

      r = FFWD.retry :timeout => RESOLVE_TIMEOUT do |a|
        unless @host_ip
          @host_ip = resolve_ip @host
          raise "Could not resolve: #{@host}" if @host_ip.nil?
        end

        @c = EM.open_datagram_socket @bind_host, nil, @handler, self, config

        unless ignored.include? :events
          @subs << core.output.event_subscribe{|e| handle_event e}
        end

        unless ignored.include? :metrics
          @subs << core.output.metric_subscribe{|m| handle_metric m}
        end

        log.info "Connect to #{info} (attempt #{a})"
        log.info "  config: #{config.inspect}"
      end

      r.error do |a, t, e|
        log.warning "Connect to #{info} failed, retry ##{a} in #{t}s: #{e}"
      end

      r.depend_on core

      core.stopping do
        if @c
          @c.close
          @c = nil
        end

        @subs.each(&:unsubscribe).clear
      end
    end

    def send_data data
      return unless @c
      @c.send_datagram data, @host_ip, @port
    end

    def unbind; end
    def connection_completed; end

    private

    def handle_event event
      unless @c
        increment :dropped_events, 1
        return
      end

      @c.send_event event
      increment :sent_events, 1
    end

    def handle_metric metric
      unless @c
        increment :dropped_metrics, 1
        return
      end

      @c.send_metric metric
      increment :sent_metrics, 1
    end

    def resolve_ip host
      Socket.getaddrinfo(@host, nil, nil, :DGRAM).each do |item|
        next if item[0] != "AF_INET"
        return item[3]
      end

      return nil
    end
  end
end
