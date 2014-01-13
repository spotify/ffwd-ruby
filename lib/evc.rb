require 'optparse'

module EVC
  def self.opts
    @@opts ||= {:debug => false}
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

  def self.main(args)
    parse_options args
    puts opts
  end
end
