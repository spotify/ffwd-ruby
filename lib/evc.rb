require 'ripl'
require 'optparse'
require 'eventmachine'

module EVC
  class TraceConnection < EM::Connection
    include EM::Protocols::LineText2

    def unbind
      EM.stop
    end

    def receive_line line
      d = JSON.load line
      p d
    end
  end

  def self.opts
    @@opts ||= {:debug => false, :host => "localhost", :port => 9999}
  end

  def self.parser
    @@parser ||= OptionParser.new do |o|
      o.banner = "Usage: evc [options]"

      o.on "-d", "--[no-]debug" do |d|
        opts[:debug] = d
      end
    end
  end

  def self.parse_options(args)
    parser.parse args
  end

  class Context
    def initialize opts
      @host = opts[:host]
      @port = opts[:port]
    end

    def trace
      EM.run do
        EM.connect(@host, @port, EVC::TraceConnection)
      end
    end
  end

  def self.main(args)
    parse_options args

    Context.new(opts).instance_eval do
      Ripl.start :binding => binding
    end
  end
end
