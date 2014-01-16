require 'yaml'
require 'optparse'

require_relative 'evd/core'
require_relative 'evd/logging'
require_relative 'evd/plugin_loader'
require_relative 'evd/plugin'

module EVD
  def self.load_config(path)
    if path.nil?
      puts "Configuration path not specified"
      puts ""
      puts EVD.parser.help
      return nil
    end

    unless File.file? path
      puts "Configuration path does not exist: #{path}"
      puts ""
      puts EVD.parser.help
      return nil
    end

    return YAML.load_file path
  rescue => e
    EVD.log.error "Failed to load config: #{path}"
    return nil
  end

  def self.opts
    @@opts ||= {:debug => false, :config => nil, :active_plugins => false,
                :list_plugins => false}
  end

  def self.parser
    @@parser ||= OptionParser.new do |o|
      o.banner = "Usage: evd [options]"

      o.on "-d", "--[no-]debug" do |d|
        opts[:debug] = d
      end

      o.on "-c", "--config <path>" do |path|
        opts[:config] = path
      end

      o.on "--list-plugins" do
        opts[:list_plugins] = true
      end

      o.on "--active-plugins" do
        opts[:active_plugins] = true
      end
    end
  end

  def self.parse_options args
    parser.parse args
  end

  def self.setup_plugins config
    plugins = {}

    plugins[:tunnel] = EVD::Plugin.load_plugins(
      log, "Tunnel", config[:tunnel], :tunnel)

    plugins[:bind] = EVD::Plugin.load_plugins(
      log, "Input", config[:bind], :bind)

    plugins[:connect] = EVD::Plugin.load_plugins(
      log, "Output", config[:connect], :connect)

    plugins
  end

  def self.main args
    parse_options args

    EVD.log_setup(
      :level => opts[:debug] ? Logger::DEBUG : Logger::INFO
    )

    config = load_config opts[:config]

    if config.nil?
      return 1
    end

    blacklist = config[:blacklist] || {}

    PluginLoader.load 'processor', blacklist[:processors] || []
    PluginLoader.load 'plugin', blacklist[:plugins] || []

    if config.nil?
      return 1
    end

    EVD::Plugin.init

    stop_early = (opts[:list_plugins] or opts[:active_plugins])

    if opts[:list_plugins]
      puts "Available Plugins:"

      EVD::Plugin.loaded.each do |name, plugin|
        puts "Plugin #{name}"
        puts "  #{plugin.caps.join(' ')}"
      end
    end

    plugins = setup_plugins config

    if opts[:active_plugins]
      puts "Activated Plugins (#{opts[:config]}):"

      plugins.each do |kind, kind_plugins|
        puts "#{kind}:"
        kind_plugins.each do |p|
          puts "  #{p.name}: #{p.config}"
        end
      end
    end

    if stop_early
      return 0
    end

    core = EVD::Core.new plugins, config
    core.run
    return 0
  end
end
