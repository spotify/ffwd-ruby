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

require 'ffwd/connection'

require_relative 'parser'
require_relative 'types_db'

module FFWD::Plugin::Collectd
  class Connection < FFWD::Connection
    def initialize bind, core, config
      @bind = bind
      @core = core
      @types_db = TypesDB.open config[:types_db]
    end

    def receive_data(data)
      Parser.parse(data) do |metric|
        plugin_key = metric[:plugin]
        type_key = metric[:type]

        if instance = metric[:plugin_instance] and not instance.empty?
          plugin_key = "#{plugin_key}-#{instance}"
        end

        if instance = metric[:type_instance] and not instance.empty?
          type_key = "#{type_key}-#{instance}"
        end

        key = "#{plugin_key}/#{type_key}"

        values = metric[:values]

        time = metric[:time]
        host = metric[:host]

        # Just add a running integer to the end of the key, the 'correct'
        # solution would have been to read, parse and match from a types.db.
        #
        # http://collectd.org/documentation/manpages/types.db.5.shtml
        if values.size > 1
          values.each_with_index do |v, i|
            if @types_db and name = @types_db.get_name(type_key, i)
              index_key = name
            else
              index_key = i.to_s
            end

            @core.input.metric(
              :key => "#{key}_#{index_key}", :time => time, :value => v[1],
              :host => host)
            @bind.increment :received_metrics
          end
        else
          v = values[0]
          @core.input.metric(
            :key => key, :time => time, :value => v[1], :host => host)
          @bind.increment :received_metrics
        end
      end
    rescue => e
      @bind.log.error "Failed to receive data", e
    end
  end
end
