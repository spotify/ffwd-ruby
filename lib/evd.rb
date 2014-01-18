require 'yaml'
require 'optparse'

require_relative 'evd/core'
require_relative 'evd/logging'
require_relative 'evd/plugin_loader'
require_relative 'evd/plugin'

module EVD
  def self.load_yaml path
    return YAML.load_file path
  rescue => e
    log.error "Failed to load config: #{path} (#{e})"
    return nil
  end

  def self.merge_configurations target, source
    if target.is_a? Hash
      raise "source not a Hash: #{source}" unless source.is_a? Hash

      source.each do |key, value|
        target[key] = merge_configurations target[key], source[key]
      end

      return
    end

    if target.is_a? Array
      raise "source not an Array: #{source}" unless source.is_a? Array
      return target + source
    end

    # override source
    return source
  end

  def self.load_config_dir dir, config
    Dir.entries(dir).sort.each do |entry|
      entry_path = File.join dir, entry

      next unless File.file? entry_path

      if entry.start_with? "."
        log.debug "Ignoring: #{entry_path} (hidden file)"
        next
      end

      c = load_yaml entry_path

      if c.nil?
        log.warn "Ignoring: #{entry_path} (invalid yaml)"
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

  def self.opts
    @@opts ||= {:debug => false, :config => nil, :config_dir => nil,
                :active_plugins => false, :list_plugins => false,
                :dump_config => false}
  end

  def self.parser
    @@parser ||= OptionParser.new do |o|
      o.banner = "Usage: evd [options]"

      o.on "-d", "--[no-]debug" do |d|
        opts[:debug] = d
      end

      o.on "-c", "--config <path>" do |path|
        opts[:config_path] = path
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

      o.on "--dump-config" do
        opts[:dump_config] = true
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

    config = {:debug => {}}

    if config_path = opts[:config_path]
      unless File.file? config_path
        puts "Configuration path does not exist: #{path}"
        puts ""
        puts parser.help
        return 1
      end

      unless source = load_yaml(config_path)
        return 0
      end

      merge_configurations config, source
    end

    if config_dir = opts[:config_dir]
      unless File.directory? config_dir
        puts "Configuration directory does not exist: #{path}"
        puts ""
        puts parser.help
        return 1
      end

      load_config_dir(config_dir, config) do |c|
        merge_configurations config, c
      end
    end

    blacklist = config[:blacklist] || {}

    PluginLoader.load 'processor', blacklist[:processors] || []
    PluginLoader.load 'plugin', blacklist[:plugins] || []

    EVD::Plugin.init

    stop_early = (opts[:list_plugins] or
                  opts[:active_plugins] or
                  opts[:dump_config])

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

    if opts[:dump_config]
      puts config
    end

    if stop_early
      return 0
    end

    core = EVD::Core.new plugins, config
    core.run
    return 0
  end
end
