require 'evd/input_plugin'
require 'evd/logging'

require 'eventmachine'

module EVD
  class InputTcpJson < InputPlugin
    include EVD::Logging

    register_input "input_tcp_json"

    class InputConnection < EventMachine::Connection
      include EventMachine::Protocols::LineText2

      def initialize(input_buffer, buffer_limit)
        @input_buffer = input_buffer
        @buffer_limit = buffer_limit
      end

      def receive_line(data)
        return if @input_buffer.size > @buffer_limit
        @input_buffer << JSON.load(data)
      rescue
        puts "Something went wrong: #{$!}"
      end
    end

    def initialize(opts={})
      @host = opts["host"] || "localhost"
      @port = opts["port"] || 3000
      @buffer_limit = opts["buffer_limit"] || 1000
    end

    def setup(buffer)
      log.info "Listening on #{@host}:#{@port}"

      EventMachine.start_server(
        @host, @port, InputConnection, buffer, @buffer_limit)
    end
  end
end
