module EVD
  class DataType
    def process(msg)
      raise Exception.new("process: Not Implemented")
    end

    class << self
      def registry
        @@registry ||= {}
      end

      def register_type(name)
        registry[name] = self
      end
    end
  end
end
