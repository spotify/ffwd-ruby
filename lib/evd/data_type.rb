module EVD
  class DataType
    attr_accessor :app

    def process(msg)
      raise Exception.new("process: Not Implemented")
    end

    def emit(data)
      app.emit(data)
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
