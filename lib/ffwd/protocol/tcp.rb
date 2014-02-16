require 'eventmachine'

require_relative '../reporter'
require_relative '../tunnel'

require_relative 'tcp/bind'
require_relative 'tcp/connect'
require_relative 'tcp/flushing_connect'

module FFWD::TCP
  def self.family
    :tcp
  end

  DEFAULT_FLUSH_PERIOD = 10
  DEFAULT_OUTBOUND_LIMIT = 2 ** 20
  DEFAULT_EVENT_LIMIT = 1000
  DEFAULT_METRIC_LIMIT = 10000
  DEFAULT_FLUSH_LIMIT = 0.8

  def self.connect opts, core, log, handler, *args
    raise "Missing required key :host" if (host = opts[:host]).nil?
    raise "Missing required key :port" if (port = opts[:port]).nil?

    outbound_limit = opts[:outbound_limit] || DEFAULT_OUTBOUND_LIMIT
    flush_period = opts[:flush_period] || DEFAULT_FLUSH_PERIOD

    if flush_period == 0
      Connect.new core, log, host, port, handler, args, outbound_limit
    else
      event_limit = opts[:event_limit] || DEFAULT_EVENT_LIMIT
      metric_limit = opts[:metric_limit] || DEFAULT_METRIC_LIMIT
      flush_limit = opts[:flush_limit] || DEFAULT_FLUSH_LIMIT

      FlushingConnect.new(
        core, log, host, port, handler, args, outbound_limit,
        flush_period, event_limit, metric_limit, flush_limit
      )
    end
  end

  DEFAULT_REBIND_TIMEOUT = 10

  def self.bind opts, core, log, handler, *args
    raise "Missing required key :host" if (host = opts[:host]).nil?
    raise "Missing required key :port" if (port = opts[:port]).nil?
    rebind_timeout = opts[:rebind_timeout] || DEFAULT_REBIND_TIMEOUT
    Bind.new core, log, host, port, handler, args, rebind_timeout
  end

  def self.tunnel opts, core, plugin, log, handler, *args
    raise "Missing required key :port" if (port = opts[:port]).nil?
    FFWD.tunnel self.family, port, core, plugin, log, handler, args
  end
end
