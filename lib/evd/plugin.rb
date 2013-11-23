module EVD
  module Output
    def setup(buffer)
      throw Exception.new("Not implemented: setup")
    end
  end

  module Plugin
    def self.registry
      @@registry ||= {}
    end

    module ClassMethods
      def register_plugin(name)
        Plugin.registry[name] = self
      end
    end

    def self.included(mod)
      mod.extend ClassMethods
    end
  end
end
