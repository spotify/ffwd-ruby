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
  rescue
    EVD.log.error "Failed to load config: #{path}", e
    return nil
  end

  def self.opts
    @@opts ||= {:debug => false, :config => nil}
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
    end
  end

  def self.parse_options args
    parser.parse args
  end

  def self.main args
    parse_options args

    EVD.log_setup(
      :level => opts[:debug] ? Logger::DEBUG : Logger::INFO
    )

    PluginLoader.load 'processor'
    PluginLoader.load 'plugin'

    config = load_config opts[:config]

    if config.nil?
      return 1
    end

    core = EVD::Core.new config
    core.run
    return 0
  end
end
