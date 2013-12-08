module EVD
  module Processor
    attr_accessor :core

    def process(msg)
      raise Exception.new("process: Not Implemented")
    end

    def emit(event)
      core.emit event
    end

    def name
      self.class.name
    end

    module ClassMethods
      def register_type(name)
        unless Processor.registry[name].nil?
          raise "Already registered '#{name}'"
        end

        Processor.registry[name] = self
      end
    end

    def self.registry
      @@registry ||= {}
    end

    def self.included(mod)
      mod.extend ClassMethods
    end
  end

  def self.data_type(name)
    Processor.registry[name]
  end
end
