require 'yaml'
require 'optparse'

require_relative 'evd/core'
require_relative 'evd/logging'
require_relative 'evd/plugin_loader'
require_relative 'evd/plugin'

module EVD
  def self.load_yaml path
    return YAML.load_file path
  rescue
    log.error "Failed to load config: #{path}"
    return nil
  end

  def self.load_config path
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

    return load_yaml path
  end

  def self.load_config_dir_yaml dir
    Dir.entries(dir).each do |entry|
      entry_path = File.join dir, entry

      next unless File.file? entry_path

      if entry.start_with? "."
        log.info "Ignoring: #{entry_path} (hidden file)"
        next
      end

      c = load_yaml entry_path

      if c.nil?
        log.info "Ignoring: #{entry_path} (invalid yaml)"
        next
      end

      yield c
    end
  end

  def self.join_array config, c, key
    (c[key] || []).each do |value|
      (config[key] ||= []) << value
    end
  end

  def self.load_config_dir dir, config
    unless File.directory? dir
      puts "Configuration directory does not exist: #{dir}"
      puts ""
      puts EVD.parser.help
      return nil
    end

    load_config_dir_yaml(dir) do |c|
      join_array config, c, :input
      join_array config, c, :output
      join_array config, c, :tunnel
    end
  end

  def self.opts
    @@opts ||= {:debug => false, :config => nil, :config_dir => nil,
                :active_plugins => false, :list_plugins => false}
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

      o.on "-d", "--config-dir <path>" do |path|
        opts[:config_dir] = path
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

    plugins[:input] = EVD::Plugin.load_plugins(
      log, "Input", config[:input], :input)

    plugins[:output] = EVD::Plugin.load_plugins(
      log, "Output", config[:output], :output)

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

    if config_dir = opts[:config_dir]
      load_config_dir config_dir, config
    end

    blacklist = config[:blacklist] || {}

    PluginLoader.load 'processor', blacklist[:processors] || []
    PluginLoader.load 'plugin', blacklist[:plugins] || []

    EVD::Plugin.init

    stop_early = (opts[:list_plugins] or opts[:active_plugins])

    if opts[:list_plugins]
      puts "Available Plugins:"

      EVD::Plugin.loaded.each do |name, plugin|
        puts "Plugin #{name}"
        puts "  #{plugin.capabilities.join(' ')}"
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
