require_relative 'logging'

module EVD
  module Plugin
    class LoadedPlugin
      attr_reader :name

      def initialize name, options
        @name = name
        @mod = options[:mod]
        @setup_input_method = load_method @mod, options[:setup_input_method_name]
        @setup_output_method = load_method @mod, options[:setup_output_method_name]
        @setup_tunnel_method = load_method @mod, options[:setup_tunnel_method_name]
      end

      def caps
        caps = []

        if @setup_input_method.nil?
          caps << "-input"
        else
          caps << "+input"
        end

        if @setup_output_method.nil?
          caps << "-output"
        else
          caps << "+output"
        end

        if @setup_tunnel_method.nil?
          caps << "-tunnel"
        else
          caps << "+tunnel"
        end
      end

      def can?(kind)
        not get(kind).nil?
      end

      def get(kind)
        return @setup_input_method if kind == :input
        return @setup_output_method if kind == :output
        return @setup_tunnel_method if kind == :tunnel
        return nil
      end

      private

      def load_method mod, method_name
        return nil unless mod.respond_to? method_name
        return mod.method method_name
      end
    end

    class SetupPlugin
      attr_reader :name, :config

      def initialize name, setup, config
        @name = name
        @setup = setup
        @config = config
      end

      def setup context
        @setup.call context, @config
      end
    end

    def self.discovered
      @@discovered ||= {}
    end

    def self.loaded
      @@loaded ||= {}
    end

    module ClassMethods
      def register_plugin(name, opts={})
        options = {:mod => self}

        options[:setup_input_method_name] = (opts[:setup_input_method] || :setup_input)
        options[:setup_output_method_name] = (opts[:setup_output_method] || :setup_output)
        options[:setup_tunnel_method_name] = (opts[:setup_tunnel_method] || :setup_tunnel)

        EVD::Plugin.discovered[name] = options
      end
    end

    def self.included mod
      mod.extend ClassMethods
    end

    def self.init
      EVD::Plugin.discovered.each do |name, options|
        EVD::Plugin.loaded[name] = LoadedPlugin.new name, options
      end
    end

    def self.load_plugins log, kind_name, config, kind
      result = []

      if config.nil?
        return result
      end

      config.each_with_index do |plugin_config, index|
        d = "#{kind_name} plugin ##{index}"

        if (name = plugin_config[:type]).nil?
          log.error "#{d}: Missing :type attribute for '#{kind_name}'"
        end

        if (plugin = EVD::Plugin.loaded[name]).nil?
          log.error "#{d}: Not an available plugin '#{name}'"
          next
        end

        unless plugin.can?(kind)
          log.error "#{d}: Not an #{kind_name} plugin '#{name}'"
          next
        end

        result << SetupPlugin.new(name, plugin.get(kind), plugin_config)
      end

      return result
    end
  end
end
