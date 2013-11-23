require 'evd/protocol'
require 'evd/plugin'
require 'evd/logging'
require 'evd/data_type'

require 'eventmachine'

module EVD
  module JsonLine
    include EVD::Plugin
    include EVD::Logging

    register_plugin "json_line"

    class JsonLineConnection < EventMachine::Connection
      include EVD::Logging
      include EventMachine::Protocols::LineText2

      def initialize(input_buffer, buffer_limit)
        @input_buffer = input_buffer
        @buffer_limit = buffer_limit
      end

      def receive_line(data)
        if @input_buffer.size > @buffer_limit
          log.warning "Buffer limit reached, dropping event"
          return
        end

        data = JSON.load(data)

        type = DataType.registry[data["$type"]]
        key = data["key"]

        return if key.nil?
        return if value.nil?

        @input_buffer << {:type => type, :key => key, :value => value}
      rescue
        puts "Something went wrong: #{$!}"
      end
    end

    class JsonLineInput
      include EVD::Logging

      def initialize(host, port, protocol, buffer_limit)
        @host = host
        @port = port
        @protocol = protocol
        @buffer_limit = buffer_limit
      end

      def setup(buffer)
        @protocol.listen(@host, @port, JsonLineConnection,
                         buffer, @buffer_limit)
        log.info "Listening on #{@protocol.name} #{@host}:#{@port}"
      end
    end

    def self.input_setup(opts={})
      host = opts[:host] || "localhost"
      port = opts[:port] || 3000
      protocol = EVD.parse_protocol(opts[:protocol] || "tcp")
      buffer_limit = opts["buffer_limit"] || 1000
      JsonLineInput.new host, port, protocol, buffer_limit
    end
  end
end
