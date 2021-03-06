# $LICENSE
# Copyright 2013-2014 Spotify AB. All rights reserved.
#
# The contents of this file are licensed under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with the
# License. You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

require 'optparse'
require 'eventmachine'
require 'json'
require 'set'
require 'logger'

require 'ffwd/debug'

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
    @@opts ||= {
      :debug => false,
      :host => "localhost",
      :port => FFWD::Debug::DEFAULT_PORT,
      :summary => false,
      :raw => false,
      :raw_threshold => 100,
      :report_interval => 10,
      :key => nil,
      :tags => nil
    }
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

      o.on "--key <key>", "Only handle events and metrics matching the specified key" do |d|
        opts[:key] = d
      end

      o.on "--tag <tag>", "Only handle event and metrics which matches the specified tag" do |d|
        opts[:tags] ||= []
        opts[:tags] << d
      end
    end
  end

  def self.parse_options(args)
    parser.parse args
  end

  class Summary
    def initialize matcher
      @matcher = matcher
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
      return if not @matcher.matches? data

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
    def initialize matcher, opts={}
      @threshold = opts[:threshold]
      @matcher = matcher
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
      return if not @matcher.matches? data

      if not @tags.nil? and not (@tags & (d["tags"] || [])).empty?
        return
      end

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

  class Matcher
    def initialize opts={}
      @key = opts[:key]
      @tags = opts[:tags]
    end

    def matches? data
      return false unless ["event", "metric"].include? data["type"]

      d = data["data"]
      return false unless d

      key = d["key"]
      return false if @key and @key != key

      tags = d["tags"]
      return false if @tags and (@tags & (tags || [])).empty?

      true
    end
  end

  def self.main(args)
    parse_options args

    matcher = Matcher.new(:key => opts[:key], :tags => opts[:tags])

    handlers = []

    if opts[:summary]
      handlers << Summary.new(matcher)
    end

    if opts[:raw]
      handlers << Raw.new(matcher, :threshold => opts[:raw_threshold])
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
