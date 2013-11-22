module EVD
  class OutputPlugin
    def setup(buffer)
      raise Exception.new("Not implemented: setup")
    end

    class << self
      def registry
        @@registry ||= {}
      end

      def register_output(name)
        registry[name] = self
      end
    end
  end
end
