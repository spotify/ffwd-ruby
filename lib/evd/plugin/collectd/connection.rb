require 'evd/logging'
require 'evd/connection'

require_relative 'parser'

module EVD::Plugin::Collectd
  class Connection < EVD::Connection
    include EVD::Logging

    def initialize input, output, types_db
      @input = input
      @types_db = types_db
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

            @input.metric(:key => "#{key}_#{index_key}", :time => time,
                          :value => v[1], :host => host)
          end
        else
          v = values[0]
          @input.metric(:key => key, :time => time, :value => v[1],
                        :host => host)
        end
      end
    rescue => e
      log.error "Failed to receive data", e
    end
  end
end
