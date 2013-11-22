require 'evd/logging'
require 'evd/plugin_loader'

require 'evd/input_plugin'
require 'evd/output_plugin'
require 'evd/data_type'

module EVD
  $log = nil

  def self.parse_options(args)
    opts = {:debug => false}

    OptionParser.new do |o|
      o.banner = "Usage: evd [opts]"

      o.on("-d", "--[no-]debug") do |d|
        opts[:debug] = d
      end
    end.parse(args)

    opts
  end

  def self.main(args)
    require 'optparse'
    require 'evd/app'

    opts = parse_options(args)

    self.log_setup(
      :level => opts[:debug] ? Logger::DEBUG : Logger::INFO
    )

    PluginLoader.load 'types'
    PluginLoader.load 'plugin'

    plugins = {:input => [], :output => []}

    plugins[:input] << InputPlugin.registry['tcp_json'].new(:host => "localhost", :port => 3000)
    plugins[:output] << OutputPlugin.registry['log'].new
    plugins[:output] << OutputPlugin.registry['log'].new(:prefix => "fuck this")

    EVD::App.new.run(plugins)
  end
end
