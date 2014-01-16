require_relative 'logging'

module EVD
  module Plugin
    class LoadedPlugin
      attr_reader :name, :options, :bind, :connect, :tunnel

      def initialize name, options
        @name = name
        @mod = options[:self]
        @bind = load_method @mod, options[:bind]
        @connect = load_method @mod, options[:connect]
        @tunnel = load_method @mod, options[:tunnel]
      end

      def caps
        caps = []

        if @bind.nil?
          caps << "+input"
        else
          caps << "-input"
        end

        if @connect.nil?
          caps << "+output"
        else
          caps << "-output"
        end

        if @tunnel.nil?
          caps << "+tunnel"
        else
          caps << "-tunnel"
        end
      end

      def can?(kind)
        not get(kind).nil?
      end

      def get(kind)
        return @bind if kind == :bind
        return @connect if kind == :connect
        return @tunnel if kind == :tunnel
        return nil
      end

      private

      def load_method mod, method_name
        return nil unless mod.respond_to? method_name
        return mod.method method_name
      end
    end

    class SetupPlugin
      attr_reader :mod, :name, :config

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
      def map_plugin plugin, opts, method_name, kind
        n = (opts[method_name] || kind)
        plugin[kind] = n
      end

      def register_plugin(name, opts={})
        plugin = {:self => self}

        plugin[:bind] = (opts[:bind_method] || :bind)
        plugin[:connect] = (opts[:connect_method] || :connect)
        plugin[:tunnel] = (opts[:tunnel_method] || :tunnel)

        Plugin.discovered[name] = plugin
      end
    end

    def self.included mod
      mod.extend ClassMethods
    end

    def self.load_plugin name, options
      LoadedPlugin.new name, options
    end

    def self.init
      EVD::Plugin.discovered.each do |name, options|
        EVD::Plugin.loaded[name] = load_plugin(name, options)
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
