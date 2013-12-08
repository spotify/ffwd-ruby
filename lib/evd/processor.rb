module EVD
  module Processor
    def process(msg)
      raise Exception.new("process: Not Implemented")
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
end
