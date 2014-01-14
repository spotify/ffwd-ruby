module EVD
  # Module to include for processors.
  #
  # Usage:
  #
  # class MyProcessor
  #   include EVD::Processor
  #
  #   register_type "my_processor"
  #
  #   def initialize opts
  #     .. read options ..
  #   end
  #
  #   def start emitter
  #     ... setup EventMachine tasks ...
  #   end
  #
  #   def process emitter, m
  #     ... process a single metric ...
  #     emitter.emit_metric ...
  #   end
  # end
  module Processor
    def process m
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
