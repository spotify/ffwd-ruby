require 'json'
require 'eventmachine'

require_relative 'logging'
require_relative 'event'
require_relative 'metric'
require_relative 'retrier'
require_relative 'lifecycle'

require_relative 'debug/tcp'

module FFWD::Debug
  module Input
    def self.serialize_event event
      event = Hash[event]

      if tags = event[:tags]
        event[:tags] = tags.to_a
      end

      event
    end

    def self.serialize_metric metric
      metric = Hash[metric]

      if tags = metric[:tags]
        metric[:tags] = tags.to_a
      end

      metric
    end
  end

  module Output
    def self.serialize_event event
      event.to_h
    end

    def self.serialize_metric metric
      metric.to_h
    end
  end

  DEFAULT_REBIND_TIMEOUT = 10

  def self.setup opts={}
    host = opts[:host] || "localhost"
    port = opts[:port] || 9999
    rebind_timeout = opts[:rebind_timeout] || DEFAULT_REBIND_TIMEOUT
    proto = FFWD.parse_protocol(opts[:protocol] || "tcp")

    if proto == FFWD::TCP
      return TCP.new host, port, rebind_timeout
    end

    throw Exception.new("Unsupported protocol '#{proto}'")
  end
end
