require_relative 'logging'

module EVD
  module Plugin
    def self.registry
      @@registry ||= {}
    end

    module ClassMethods
      def register_plugin(name)
        Plugin.registry[name] = self
      end
    end

    def self.included mod
      mod.extend ClassMethods
    end

    def self.load_plugins log, plugin_type, config, setup_method
      result = []

      if config.nil?
        return result
      end

      config.each_with_index do |plugin_config, index|
        d = "#{plugin_type} plugin ##{index}"

        if (type = plugin_config[:type]).nil?
          log.error "#{d}: Missing :type attribute for '#{plugin_type}'"
        end

        if (plugin = EVD::Plugin.registry[type]).nil?
          log.error "#{d}: Not an available plugin '#{type}'"
          next
        end

        unless plugin.respond_to? setup_method
          log.error "#{d}: Not an #{plugin_type} plugin '#{type}'"
          next
        end

        result << [plugin, plugin_config]
      end

      return result
    end
  end
end
