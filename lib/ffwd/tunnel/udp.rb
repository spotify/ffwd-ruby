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

require_relative '../lifecycle'
require_relative '../reporter'

module FFWD::Tunnel
  class UDP
    include FFWD::Lifecycle
    include FFWD::Reporter

    report_meta :protocol => :tunnel_udp

    report_key :received_events, :meta => {:what => "received-events", :unit => :event}
    report_key :received_metrics, :meta => {:what => "received-metrics", :unit => :metric}

    report_key :failed_events, :meta => {:what => "failed-events", :unit => :event}
    report_key :failed_metrics, :meta => {:what => "failed-metrics", :unit => :metric}

    attr_reader :log

    def initialize port, core, plugin, log, connection, args
      @port = port
      @core = core
      @plugin = plugin
      @log = log
      @connection = connection
      @args = args

      @instance = nil

      starting do
        @instance = @connection.new(nil, self, @core, *@args)

        @plugin.udp @port do |handle, data|
          @instance.datasink = handle
          @instance.receive_data data
          @instance.datasink = nil
        end

        @log.info "Tunneling udp/#{@port}"
      end

      stopping do
        if @instance
          @instance.unbind
          @instance = nil
        end

        @log.info "Stopped tunnelling udp/#{@port}"
      end
    end
  end
end
