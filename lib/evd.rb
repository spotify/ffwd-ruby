require 'evd/logging'

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

    require 'evd/plugin/input_tcp_json'

    opts = parse_options(args)

    self.log_setup(
      :level => opts[:debug] ? Logger::DEBUG : Logger::INFO
    )

    plugins = {:input => []}

    plugins[:input] << InputTcpJson.new(:host => "localhost", :port => 3000)

    EVD::App.new.run(plugins)
  end
end
