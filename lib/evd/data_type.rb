module EVD
  module DataType
    attr_accessor :core

    def process(msg)
      raise Exception.new("process: Not Implemented")
    end

    def emit(data)
      core.emit(data)
    end

    def name
      self.class.name
    end

    module ClassMethods
      def register_type(name)
        unless DataType.registry[name].nil?
          raise "Already registered '#{name}'"
        end

        DataType.registry[name] = self
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
    DataType.registry[name]
  end
end
