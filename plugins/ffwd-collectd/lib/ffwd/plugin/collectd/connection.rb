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
      @db = TypesDB.open config[:types_db]
      @key = config[:key]
    end

    def receive_data(data)
      Parser.parse(data) do |m|
        plugin = m[:plugin]
        type = m[:type]
        plugin_i = m[:plugin_instance]
        type_i = m[:type_instance]

        read_values(plugin, plugin_i, type, type_i, m[:values]) do |a, v|
          @core.input.metric(
            :key => @key, :time => m[:time], :value => v,
            :host => m[:host], :attributes => a)
          @bind.increment :received_metrics
        end
      end
    rescue => e
      @bind.log.error "Failed to receive data", e
    end

    def read_values(plugin, plugin_i, type, type_i, values, &block)
      if values.size == 1
        return read_single(plugin, plugin_i, type, type_i, values[0], &block)
      end

      read_multiple(plugin, plugin_i, type, type_i, values, &block)
    end

    def read_single(plugin, plugin_i, type, type_i, v)
      a = {:plugin => plugin, :type => type}
      a[:plugin_instance] = plugin_i unless plugin_i.nil? or plugin_i.empty?
      a[:type_instance] = type_i unless type_i.nil? or type_i.empty?
      a[:value_type] = v[0]
      a[:what] = format_what(a)
      yield a, v[1]
    end

    # Handle payload with multiple values.
    #
    # If a database is not available, plugin_instance becomes the running
    # integer, or index of the value.
    #
    # If a database is avaialble, it would follow the current structure and
    # determine what the name of the plugin_instance is.
    #
    # http://collectd.org/documentation/manpages/types.db.5.shtml
    def read_multiple(plugin, plugin_i, type, type_i, values)
      values.each_with_index do |v, i|
        a = {:plugin => plugin, :type => type}
        a[:plugin_instance] = plugin_i unless plugin_i.nil? or plugin_i.empty?
        a[:type_instance] = format_type_instance(type, i)
        a[:value_type] = v[0]
        a[:what] = format_what(a)
        yield a, v[1]
      end
    end

    def format_type_instance type, i
      if @db
        return @db.get_name(type, i)
      end

      i.to_s
    end

    def format_what a
      p = if a[:plugin_instance]
            "#{a[:plugin]}-#{a[:plugin_instance]}"
          else
            a[:plugin].to_s
          end

      t = if a[:type_instance]
            "#{a[:type]}-#{a[:type_instance]}"
          else
            a[:type].to_s
          end

      "#{p}/#{t}"
    end
  end
end
