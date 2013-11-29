require 'yaml'
require 'optparse'

require 'evd/core'
require 'evd/logging'
require 'evd/plugin_loader'

require 'evd/plugin'
require 'evd/data_type'

module EVD
  class CommandLine
    include EVD::Logging

    def load_plugins(config, plugin_type, setup_method)
      (config[plugin_type] || []).each_with_index do |plugin_config, index|
        d = "#{plugin_type} plugin ##{index}"

        if (type = plugin_config[:type]).nil?
          log.error "#{d}: Missing :type attribute for '#{plugin_type}'"
        end

        if (plugin = Plugin.registry[type]).nil?
          log.error "#{d}: Not an available plugin '#{type}'"
          next
        end

        unless plugin.respond_to? setup_method
          log.error "#{d}: Not an #{plugin_type} plugin '#{type}'"
          next
        end

        yield plugin.send setup_method, plugin_config
      end
    end

    def load_config(path)
      if path.nil?
        log.info "Configuration path not specified"
        puts EVD.parser.help
        return nil
      end

      unless File.file? path
        log.info "Configuration path does not exist: #{path}"
        puts EVD.parser.help
        return nil
      end

      config = YAML.load_file(path)

      plugins = {:input => [], :output => []}

      load_plugins(config, :output, :output_setup) do |output|
        plugins[:output] << output
      end

      load_plugins(config, :input, :input_setup) do |input|
        plugins[:input] << input
      end

      return plugins, config
    end

    def main(opts)
      PluginLoader.load 'type'
      PluginLoader.load 'plugin'

      result = load_config opts[:config]

      return 1 if result.nil?

      plugins, opts = result

      core = EVD::Core.new(opts)

      core.run(plugins)
    end
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

  def self.parse_options(args)
    parser.parse args
  end

  def self.main(args)
    parse_options(args)

    EVD.log_setup(
      :level => opts[:debug] ? Logger::DEBUG : Logger::INFO
    )

    CommandLine.new.main(opts)
  end
end
