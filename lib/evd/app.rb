require 'json'
require 'eventmachine'

require 'evd/logging'
require 'evd/data_type'
require 'evd/plugin_loader'

module EVD
  class App
    include EVD::Logging

    def initialize
      PluginLoader.load 'types'
      PluginLoader.load 'plugin'
    end

    def run(plugins)
      @datatypes = setup_datatypes

      input_buffer = EM::Queue.new

      input_plugins = plugins[:input]

      EventMachine.run do
        input_plugins.each do |plugin|
          plugin.setup input_buffer
        end

        process_input_buffer input_buffer
      end
    end

    # Is called whenever a DataType has finished processing a value.
    def emit(event)
      log.info "emit: #{event}"
    end

    private

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

    def process_input_buffer(input_buffer)
      input_buffer.pop do |msg|
        process_message msg
        process_input_buffer input_buffer
      end
    end

    def process_message(msg)
      log.info "Received message: #{msg}"

      return unless msg.is_a? Hash

      type = msg["$type"]
      return if type.nil?

      data_type = @datatypes[type]
      return if data_type.nil?

      msg["time"] = Time.now unless msg["time"]

      data_type.process msg
    end
  end
end
