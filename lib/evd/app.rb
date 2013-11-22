require 'json'
require 'eventmachine'

require 'evd/logging'
require 'evd/data_type'

module EVD
  class App
    def initialize
      require 'evd/types/derive'
      require 'evd/types/count'
    end

    def run(plugins)
      @registry = setup_registry

      input_buffer = EM::Queue.new

      input_plugins = plugins[:input]

      EventMachine.run do
        input_plugins.each do |plugin|
          plugin.setup input_buffer
        end

        process_one input_buffer
      end
    end

    def emit(event)
      puts event
    end

    private

    def setup_registry
      registry = {}

      DataType.registry.each do |name, klass|
        registry[name] = klass.new(self)
      end

      registry
    end

    def process_one(input_buffer)
      input_buffer.pop do |msg|
        process_message msg
        process_one input_buffer
      end
    end

    def process_message(msg)
      return unless msg.is_a? Hash

      type = msg["$type"]
      return if type.nil?

      instance = @registry[type]
      return if instance.nil?

      msg["time"] = Time.now unless msg["time"]

      instance.process msg
    end
  end
end
