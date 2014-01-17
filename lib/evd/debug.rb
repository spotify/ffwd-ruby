require 'json'
require 'eventmachine'

require_relative 'logging'
require_relative 'event'
require_relative 'metric'

require_relative 'debug/connection'
require_relative 'debug/monitor_session'

module EVD::Debug
  module Input
    def self.serialize_event event
      event = Hash[event]

      if tags = event[:tags]
        event[:tags] = tags.to_a
      end
    end

    def self.serialize_metric metric
      metric = Hash[metric]

      if tags = metric[:tags]
        metric[:tags] = tags.to_a
      end
    end
  end

  module Output
    def self.serialize_event event
      EVD.event_to_h event
    end

    def self.serialize_metric metric
      EVD.metric_to_h metric
    end
  end

  class TCP
    include EVD::Logging

    def initialize host, port
      @clients = {}
      @sessions = {}
      @host = host
      @port = port
      @peer = "#{@host}:#{@port}"
    end

    def start
      log.info "Binding on tcp://#{@peer}"
      EM.start_server @host, @port, Connection, self
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

      session.start
    end

    def unmonitor id
      if session = @sessions[id]
        session.stop
        @sessions.delete id
      end
    end
  end

  def self.setup opts={}
    host = opts[:host] || "localhost"
    port = opts[:port] || 9999
    proto = EVD.parse_protocol(opts[:protocol] || "tcp")

    if proto == EVD::TCP
      return TCP.new host, port
    end

    throw Exception.new("Unsupported protocol '#{proto}'")
  end
end
