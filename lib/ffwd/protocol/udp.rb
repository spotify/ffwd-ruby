require 'eventmachine'

require_relative '../reporter'
require_relative '../tunnel'

module FFWD::UDP
  class Connect
    include FFWD::Reporter

    set_reporter_keys :dropped_events, :dropped_metrics,
                      :sent_events, :sent_metrics

    def initialize log, host, port, handler
      @log = log
      @host = host
      @port = port
      @handler = handler

      @bind_host = "0.0.0.0"
      @host_ip = nil
      @connection = nil
      @peer = "#{host}:#{port}"
    end

    def id
      @id ||= "#{@handler.name}/#{@peer}"
    end

    def start output
      @host_ip = resolve_host_ip @host

      if @host_ip.nil?
        @log.error "Could not resolve '#{@host}'"
        return
      end

      @log.info "Resolved server as #{@host_ip}"

      EM.open_datagram_socket(@bind_host, nil) do |connection|
        @connection = connection
      end

      output.event_subscribe{|e| handle_event e}
      output.metric_subscribe{|m| handle_metric m}
    end

    private

    def handle_event event
      unless @connection
        increment :dropped_events, 1
        return
      end

      data = @handler.serialize_event event
      @connection.send_datagram data, @host_ip, @port
      increment :sent_events, 1
    end

    def handle_metric metric
      unless @connection
        increment :dropped_metrics, 1
        return
      end

      data = @handler.serialize_metric metric
      @connection.send_datagram data, @host_ip, @port
      increment :sent_metrics, 1
    end

    def resolve_host_ip host
      Socket.getaddrinfo(@host, nil, nil, :DGRAM).each do |item|
        next if item[0] != "AF_INET"
        return item[3]
      end

      return nil
    end
  end

  class Bind
    def initialize log, host, port, handler, *args
      @host = host
      @port = port
      @handler = handler
      @log = log
      @args = args
      @peer = "#{@host}:#{@port}"
    end

    def start input, output
      @log.info "Binding to udp://#{@peer}"
      EM.open_datagram_socket(@host, @port, @handler, input, output, *@args)
    end
  end

  def self.family
    :udp
  end

  def self.connect log, opts, handler
    raise "Missing required key :host" if (host = opts[:host]).nil?
    raise "Missing required key :port" if (port = opts[:port]).nil?
    Connect.new log, host, port, handler
  end

  def self.bind log, opts, handler, *args
    raise "Missing required key :host" if (host = opts[:host]).nil?
    raise "Missing required key :port" if (port = opts[:port]).nil?
    Bind.new log, host, port, handler, *args
  end

  def self.tunnel log, opts, handler, *args
    raise "Missing required key :port" if (port = opts[:port]).nil?
    FFWD::Tunnel.new log, self.family, port, handler, args
  end
end

