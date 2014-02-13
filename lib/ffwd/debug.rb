require 'json'
require 'eventmachine'

require_relative 'logging'
require_relative 'event'
require_relative 'metric'
require_relative 'retrier'
require_relative 'lifecycle'

require_relative 'debug/connection'
require_relative 'debug/monitor_session'

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

  class TCP
    include FFWD::Logging
    include FFWD::Lifecycle

    def initialize host, port, rebind_timeout
      @clients = {}
      @sessions = {}
      @host = host
      @port = port
      @peer = "#{@host}:#{@port}"

      r = FFWD::Retrier.new(log, self, rebind_timeout) do |attempt|
        EM.start_server @host, @port, Connection, self
        log.info "Bind on tcp://#{@peer} (attempt #{attempt})"
      end

      r.error do |attempt, timeout, e|
        log.error "Failed to bind tcp://#{@peer} (attempt #{attempt}), retry in #{timeout}s", e
      end
    end

    def register_client peer, client
      @sessions.each do |id, session|
        session.register peer, client
      end

      @clients[peer] = client
    end

    def unregister_client peer, client
      @sessions.each do |id, session|
        session.unregister peer, client
      end

      @clients.delete peer
    end

    # Setup monitor hooks for the specified input and output channel.
    def monitor id, channel, type
      if session = @sessions[id]
        log.error "Session already monitored: #{id}"
        return
      end

      session = @sessions[id] = MonitorSession.new id, channel, type

      # provide the session to the already connected clients.
      @clients.each do |peer, client|
        session.register peer, client
      end
    end

    def unmonitor id
      if session = @sessions[id]
        session.stop
        @sessions.delete id
      end
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
