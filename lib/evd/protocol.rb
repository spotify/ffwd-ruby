module EVD
  module UNIXUDP
    class Listen
      def initialize(log, path, handler, *args)
        @log = log
        @path = path
        @handler = handler
        @args = args
      end

      def start(buffer)
        @log.info "Listening on unix+udp://#{@path}"

        File.unlink @path if File.exists? @path

        s = Socket.new(Socket::AF_UNIX, Socket::SOCK_DGRAM, 0)
        s.bind(Socket.pack_sockaddr_un(@path))

        EventMachine.attach(s, @handler, buffer, *@args)
      end
    end

    def self.listen(log, opts, handler, *args)
      raise "Missing configuration ':path'" if (path = opts[:path]).nil?
      Listen.new log, path, handler, *args
    end
  end

  module UDP
    class Connect
      def initialize(log, host, port, handler)
        @log = log
        @host = host
        @port = port
        @handler = handler

        @bind_host = "0.0.0.0"
        @host_ip = nil
        @c = nil
      end

      def start(buffer)
        @host_ip = resolve_host_ip @host

        if @host_ip.nil?
          @log.error "Could not resolve '#{@host}'"
          return
        end

        @log.info "Resolved server as #{@host_ip}"

        EventMachine.open_datagram_socket(@bind_host, nil) do |c|
          @c = c
          collect_events buffer
        end
      end

      private

      def handle_event(event)
        data = @handler.serialize_event event
        @c.send_datagram data, @host_ip, @port
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

    class Listen
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
        EventMachine.open_datagram_socket(@host, @port, @handler, b, *@args)
      end
    end

    def self.connect(log, opts, handler)
      raise "Missing required key :host" if (host = opts[:host]).nil?
      raise "Missing required key :port" if (port = opts[:port]).nil?
      Connect.new log, host, port, handler
    end

    def self.listen(log, opts, handler, *args)
      raise "Missing required key :host" if (host = opts[:host]).nil?
      raise "Missing required key :port" if (port = opts[:port]).nil?
      Listen.new log, host, port, handler, *args
    end
  end

  module TCP
    class Connection < EventMachine::Connection
      INITIAL_TIMEOUT = 2

      def initialize(log, host, port, handler)
        @log = log
        @host = host
        @port = port
        @handler = handler

        @peer = "#{host}:#{port}"
        @timeout = INITIAL_TIMEOUT

        @connected = false
        @timer = nil
      end

      def connected?
        @connected
      end

      def connection_completed
        @connected = true

        @log.info "Connected tcp://#{@peer}"

        unless @timer.nil?
          @timer.cancel
          @timer = nil
        end

        @timeout = INITIAL_TIMEOUT
      end

      def unbind
        @connected = false

        @log.info "Disconnected tcp://#{@peer}, reconnect in #{@timeout}s"

        @timer = EventMachine::Timer.new(@timeout) do
          @timeout *= 2
          @timer = nil
          reconnect @host, @port
        end
      end

      def recv_data(data)
        @handler.recv_data @peer, data
      end
    end

    class Connect
      def initialize(log, host, port, handler, flush_period)
        @log = log
        @host = host
        @port = port
        @handler = handler
        @flush_period = flush_period

        @peer = "#{host}:#{port}"
        @c = nil
        @buffer = []
      end

      #
      # start riemann tcp connection.
      #
      def start(buffer)
        EventMachine.connect(@host, @port, Connection, @log, @host, @port, @handler) do |c|
          @c = c
        end

        EventMachine::PeriodicTimer.new(@flush_period) do
          flush_events
        end

        collect_events buffer
      end

      private

      #
      # Flush buffered events (if any).
      #
      def flush_events
        return if @buffer.empty?
        return unless @c.connected?
        data = @handler.serialize_events @buffer
        @c.send_data data
      rescue => e
        @log.error "Failed to send events: #{e}"
        @log.error e.backtrace.join("\n")
      ensure
        @buffer = []
      end

      def collect_events(buffer)
        buffer.pop do |event|
          @buffer << event
          collect_events buffer
        end
      end
    end

    def self.connect(log, opts, handler)
      raise "Missing required key :host" if (host = opts[:host]).nil?
      raise "Missing required key :port" if (port = opts[:port]).nil?
      flush_period = opts[:flush_period] || 10
      Connect.new log, host, port, handler, flush_period
    end

    class Listen
      def initialize(log, host, port, handler, *args)
        @log = log
        @host = host
        @port = port
        @handler = handler
        @args = args

        @peer = "#{host}:#{port}"
      end

      def start(buffer)
        @log.info "Listening on tcp://#{@peer}"
        EventMachine.start_server @host, @port, @handler, buffer, *@args
      end
    end

    def self.listen(log, opts, handler, *args)
      raise "Missing required key :host" if (host = opts[:host]).nil?
      raise "Missing required key :port" if (port = opts[:port]).nil?
      Listen.new log, host, port, handler, *args
    end
  end

  def self.parse_protocol(original)
    string = original.downcase

    return UDP if string == "udp"
    return UNIXUDP if string == "unix+udp"
    return TCP if string == "tcp"

    throw "Unknown protocol '#{original}'"
  end
end
