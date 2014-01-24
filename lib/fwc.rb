require 'optparse'
require 'eventmachine'
require 'json'
require 'set'
require 'logger'

module FWC
  def self.log
    @logger ||= ::Logger.new(STDOUT).tap do |l|
      l.level = Logger::INFO
      l.formatter = proc do |severity, datetime, progname, msg|
        t = datetime.strftime("%H:%M:%S")
        "#{t} #{severity}: #{msg}\n"
      end
    end
  end

  class TraceConnection < EM::Connection
    include EM::Protocols::LineText2

    def initialize instances
      @instances = instances
    end

    def unbind
      FWC.log.error "Connection lost"
      EM.stop
    end

    def receive_line line
      data = JSON.load line

      @instances.each do |instance|
        instance.receive data
      end
    end
  end

  def self.opts
    @@opts ||= {:debug => false, :host => "localhost", :port => 9999,
                :summary => false,
                :raw => false,
                :raw_threshold => 100,
                :report_interval => 10}
  end

  def self.parser
    @@parser ||= OptionParser.new do |o|
      o.banner = "Usage: fwc [options]"

      o.on "-d", "--[no-]debug" do |d|
        opts[:debug] = d
      end

      o.on "-s", "--summary", "Show a periodic summary of everything seen" do
        opts[:summary] = true
      end

      o.on "-r", "--raw", "Display raw metrics and events, as soon as they are seen" do
        opts[:raw] = true
      end

      o.on "--raw-threshold <rate>", "Limit of how many messages/s is allowed before disabling output" do |d|
        opts[:raw_threshold] = d.to_i
      end

      o.on "-i", "--report-interval", "Interval in seconds to generate report" do |d|
        opts[:report_interval] = d.to_i
      end
    end
  end

  def self.parse_options(args)
    parser.parse args
  end

  class Summary
    def initialize
      @groups = {}
    end

    def report!
      return if @groups.empty?

      FWC.log.info "Summary Report:"

      @groups.sort.each do |id, group|
        items = group[:items].to_a

        FWC.log.info "  #{group[:id]} (#{group[:type]})"
        items.sort.each do |key, count|
          key = "<nil>" if key.nil?
          FWC.log.info "    #{key} #{count}"
        end
      end

      @groups = {}
    end

    def receive data
      id = [data["id"], data["type"]]
      group = (@groups[id] ||= {:id => data["id"], :type => data["type"],
                                :items => {}})

      key = data["data"]["key"]
      items = group[:items]

      if v = items[key]
        items[key] = v + 1
      else
        items[key] = 1
      end
    end
  end

  class Raw
    def initialize threshold
      @threshold = threshold
      @count = 0
      @rate = 0
      @disabled = false
      @first = Time.now
    end

    def report!
      return if @count == 0

      FWC.log.info "Raw Report:"
      FWC.log.info "  count: #{@count}"

      @first = Time.now
      @count = 0
      @disabled = false
    end

    def receive data
      if not @disabled and @count > 100
        diff = (Time.now - @first)
        rate = (@count / diff)

        if rate > @threshold
          r = rate.to_i
          desc = "#{r}/s > #{@threshold}/s"
          FWC.log.info "Raw: disabled - rate too high (#{desc})"
          @disabled = true
        end
      end

      unless @disabled
        FWC.log.info "#{@count}: #{data}"
      end

      @count += 1
    end
  end

  def self.main(args)
    parse_options args

    handlers = []

    if opts[:summary]
      handlers << Summary.new
    end

    if opts[:raw]
      handlers << Raw.new(opts[:raw_threshold])
    end

    if handlers.empty?
      puts "No methods specified"
      return 1
    end

    EM.run do
      EM.connect(opts[:host], opts[:port], FWC::TraceConnection, handlers)

      EM::PeriodicTimer.new(opts[:report_interval]) do
        handlers.each(&:report!)
      end
    end

    return 0
  end
end
