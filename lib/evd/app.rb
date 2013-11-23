require 'json'
require 'eventmachine'

require 'evd/logging'
require 'evd/data_type'
require 'evd/protocol'
require 'evd/debug'

module EVD
  class App
    include EVD::Logging

    def initialize(opts={})
      @input_buffer = EventMachine::Queue.new
      @output_buffer = EventMachine::Queue.new
      @output_buffers = []

      @statistics_period = opts[:statistics_period] || 10
      @output_buffer_limit = opts[:output_buffer_limit] || 1000
      @debug = opts[:debug] || false

      @debug_clients = {}
      @debug_protocol = TCPProtocol
      @debug_host = opts[:debug_host] || "localhost"
      @debug_port = opts[:debug_port] || 9999

      @s_input_count = 0
      @s_output_count = 0
      @s_then = nil
    end

    def run(plugins)
      @datatypes = setup_datatypes
      @s_then = Time.new

      input_plugins = plugins[:input]
      output_plugins = plugins[:output]

      EventMachine.run do
        input_plugins.each do |plugin|
          plugin.setup @input_buffer
        end

        output_plugins.each do |plugin|
          output_buffer = EventMachine::Queue.new
          plugin.setup output_buffer
          @output_buffers << output_buffer
        end

        @datatypes.each do |name, datatype|
          next unless datatype.respond_to?(:setup)
          datatype.setup
        end

        process_input_buffer
        process_output_buffer

        EventMachine::PeriodicTimer.new(@statistics_period) do
          generate_statistics
        end

        if @debug
          @debug_protocol.listen(@debug_host, @debug_port, DebugConnection, @debug_clients)
          log.info "Listening #{@debug_protocol.name} on #{@debug_host}:#{@debug_port}"
        end
      end
    end

    # Is called whenever a DataType has finished processing a value.
    def emit(event)
      emit_debug event if @debug
      emit_output event
    end

    private

    def emit_debug(event)
      @debug_clients.each do |peer, client|
        data = JSON.dump(event)
        client.send_data "#{data}\n"
      end
    end

    def emit_output(event)
      if @output_buffer.size > @output_buffer_limit
        log.warning "Output buffer limit reached, dropping event"
        return
      end

      @output_buffer << event
    end

    def generate_statistics()
      now = Time.new
      diff = (now - @s_then)
      input_rate = @s_input_count / diff
      output_rate = @s_output_count / diff

      emit(:key => 'evd.input_rate', :value => input_rate)
      emit(:key => 'evd.output_rate', :value => output_rate)

      @s_then = now
      @s_output_count = 0
    end

    def setup_datatypes
      datatypes = {}

      DataType.registry.each do |name, klass|
        log.info "DataType: #{name}"

        data_type = klass.new
        data_type.app = self
        datatypes[name] = data_type
      end

      datatypes
    end

    def process_input_buffer
      @input_buffer.pop do |msg|
        @s_input_count += 1
        process_input msg
        process_input_buffer
      end
    end

    def process_output_buffer
      @output_buffer.pop do |event|
        @s_output_count += 1
        process_output event
        process_output_buffer
      end
    end

    def process_input(msg)
      type = msg[:type]
      return if type.nil?

      data_type = @datatypes[type]
      return if data_type.nil?

      msg[:time] = Time.now unless msg[:time]

      data_type.process msg
    end

    def process_output(event)
      @output_buffers.each do |buffer|
        if buffer.size > @output_buffer_limit
          log.warning "Output buffer limit reached, dropping event for plugin"
          next
        end

        buffer << event
      end
    end
  end
end
