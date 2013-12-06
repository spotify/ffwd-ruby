module EVD::UDP
  class Client
    def initialize(log, host, port, handler)
      @log = log
      @host = host
      @port = port
      @handler = handler

      @bind_host = "0.0.0.0"
      @host_ip = nil
      @connection = nil
    end

    def start(buffer)
      @host_ip = resolve_host_ip @host

      if @host_ip.nil?
        @log.error "Could not resolve '#{@host}'"
        return
      end

      @log.info "Resolved server as #{@host_ip}"

      EM.open_datagram_socket(@bind_host, nil) do |connection|
        @connection = connection
        collect_events buffer
      end
    end

    private

    def handle_event(event)
      data = @handler.serialize_event event
      @connection.send_datagram data, @host_ip, @port
    end

    def collect_events(buffer)
      buffer.pop do |event|
        handle_event event
        collect_events buffer
      end
    end

    def resolve_host_ip(host)
      Socket.getaddrinfo(@host, nil, nil, :DGRAM).each do |item|
        next if item[0] != "AF_INET"
        return item[3]
      end

      return nil
    end
  end

  class Server
    def initialize(log, host, port, handler, *args)
      @host = host
      @port = port
      @handler = handler
      @log = log
      @args = args
      @peer = "#{@host}:#{@port}"
    end

    def start(b)
      @log.info "Listening on udp://#{@peer}"
      EM.open_datagram_socket(@host, @port, @handler, b, *@args)
    end
  end

  def self.family; :udp; end

  def self.connect(log, opts, handler)
    raise "Missing required key :host" if (host = opts[:host]).nil?
    raise "Missing required key :port" if (port = opts[:port]).nil?
    Client.new log, host, port, handler
  end

  def self.listen(log, opts, handler, *args)
    raise "Missing required key :host" if (host = opts[:host]).nil?
    raise "Missing required key :port" if (port = opts[:port]).nil?
    Server.new log, host, port, handler, *args
  end
end

