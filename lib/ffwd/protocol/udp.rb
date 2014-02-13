require 'eventmachine'

require_relative 'udp/connect'
require_relative 'udp/bind'

require_relative '../reporter'
require_relative '../tunnel'

module FFWD::UDP
  def self.family
    :udp
  end

  def self.connect opts, core, log, handler
    raise "Missing required key :host" if (host = opts[:host]).nil?
    raise "Missing required key :port" if (port = opts[:port]).nil?
    Connect.new core.output, log, host, port, handler
  end

  DEFAULT_REBIND_TIMEOUT = 10

  def self.bind opts, core, log, handler, *args
    raise "Missing required key :host" if (host = opts[:host]).nil?
    raise "Missing required key :port" if (port = opts[:port]).nil?
    rebind_timeout = opts[:rebind_timeout] || DEFAULT_REBIND_TIMEOUT
    Bind.new core, log, host, port, handler, args, rebind_timeout
  end

  def self.tunnel opts, core, tunnel, log, handler, *args
    raise "Missing required key :port" if (port = opts[:port]).nil?
    FFWD::Tunnel.new core, tunnel, log, self.family, port, handler, args
  end
end

