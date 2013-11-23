require 'json'
require 'eventmachine'

require 'evd/logging'
require 'evd/data_type'

module EVD
  class App
    include EVD::Logging

    def initialize(opts={})
      @input_buffer = EventMachine::Queue.new
      @output_buffer = EventMachine::Queue.new
      @output_buffers = []
      @s_count = 0
      @s_then = nil
      @statistics_period = opts[:statistics_period] || 10
      @output_buffer_limit = opts[:output_buffer_limit] || 1000
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

        process_input_buffer
        process_output_buffer

        EventMachine::PeriodicTimer.new(@statistics_period) do
          generate_statistics
        end
      end
    end

    # Is called whenever a DataType has finished processing a value.
    def emit(event)
      if @output_buffer.size > @output_buffer_limit
        log.warning "Output buffer limit reached, dropping event"
        return
      end

      @output_buffer << event
    end

    private

    def generate_statistics()
      now = Time.new
      diff = (now - @s_then)
      rate = @s_count / diff

      emit(:key => 'evd/rate', :value => rate)

      @s_then = now
      @s_count = 0
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
        process_input msg
        process_input_buffer
      end
    end

    def process_output_buffer
      @output_buffer.pop do |event|
        @s_count += 1
        process_output event
        process_output_buffer
      end
    end

    def process_input(msg)
      return unless msg.is_a? Hash

      type = msg["$type"]
      return if type.nil?

      data_type = @datatypes[type]
      return if data_type.nil?

      msg["time"] = Time.now unless msg["time"]

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
