require 'json'
require 'eventmachine'

require_relative 'logging'
require_relative 'event'
require_relative 'metric'

module EVD::Debug
  class Connection < EM::Connection
    include EVD::Logging

    def initialize clients
      @clients = clients
      @peer = nil
      @ip = nil
      @port = nil
    end

    def get_peer
      peer = get_peername
      port, ip = Socket.unpack_sockaddr_in(peer)
      return peer, ip, port
    end

    def post_init
      @peer, @ip, @port = get_peer
      @clients[@peer] = self
      log.info "#{@ip}:#{@port}: connected"
    end

    def unbind
      @clients.delete @peer
      log.info "#{@ip}:#{@port}: disconnected"
    end

    def receive_data(data)
    end
  end

  class TCP
    include EVD::Logging

    def initialize host, port
      @clients = {}
      @host = host
      @port = port
      @peer = "#{@host}:#{@port}"
    end

    def start
      log.info "Binding on tcp://#{@peer}"
      EM.start_server(@host, @port, Connection, @clients)
    end

    def handle_event name, event
      return if @clients.empty?

      begin
        d = JSON.dump(:type => :event, :data => EVD.event_to_h(event))
      rescue => e
        log.error "Failed to serialize event", e
        return
      end

      @clients.each do |peer, c|
        c.send_data "#{d}\n"
      end
    end

    def handle_metric name, metric
      return if @clients.empty?

      begin
        d = JSON.dump(:type => :metric, :data => EVD.metric_to_h(metric))
      rescue => e
        log.error "Failed to serialize metric", e
        return
      end

      @clients.each do |peer, c|
        c.send_data "#{d}\n"
      end
    end
  end

  def self.setup(clients, opts={})
    host = opts[:host] || "localhost"
    port = opts[:port] || 9999
    proto = EVD.parse_protocol(opts[:protocol] || "tcp")

    if proto == EVD::TCP
      return TCP.new host, port
    end

    throw Exception.new("Unsupported protocol '#{proto}'")
  end
end
