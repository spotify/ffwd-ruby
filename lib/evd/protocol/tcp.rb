module EVD::TCP
  class Connection < EventMachine::Connection
    def initialize(parent)
      @parent = parent
    end

    def connection_completed
      @parent.connection_completed
    end

    def unbind
      @parent.unbind
    end

    def receive_data(data)
      @parent.receive_data data
    end
  end

  class Client
    INITIAL_TIMEOUT = 2

    def initialize(log, host, port, handler, flush_period)
      @log = log
      @host = host
      @port = port
      @handler = handler
      @flush_period = flush_period

      @peer = "#{host}:#{port}"
      @connection = nil
      @buffer = []
      @reconnect_timer = nil
      @reconnect_timeout = INITIAL_TIMEOUT
      @connected = false
    end

    def connection_completed
      @connected = true
      @log.info "Connected tcp://#{@peer}"

      @reconnect_timeout = INITIAL_TIMEOUT

      unless @reconnect_timer.nil?
        @reconnect_timer.cancel
        @reconnect_timer = nil
      end
    end

    def unbind
      @connected = false

      @log.info "Disconnected from tcp://#{@peer}, reconnecting in #{@reconnect_timeout}s"

      unless @reconnect_timer.nil?
        @reconnect_timer.cancel
        @reconnect_timer = nil
      end

      @reconnect_timer = EventMachine::Timer.new(@reconnect_timeout) do
        @reconnect_timeout *= 2
        @reconnect_timer = nil
        @connection.reconnect @host, @port
      end
    end

    def receive_data(data)
      @handler.receive_data data
    end

    # Start TCP connection.
    def start(buffer)
      @connection = EventMachine.connect(@host, @port, Connection, self)

      if @flush_period == 0
        collect_events buffer
        return
      end

      @log.info "Flushing every #{@flush_period}s"

      EventMachine::PeriodicTimer.new(@flush_period) do
        flush_events
      end

      collect_events_buffer buffer
    end

    private

    # Flush buffered events (if any).
    def flush_events
      return if @buffer.empty?
      return unless @connected
      data = @handler.serialize_events @buffer
      @connection.send_data data
    rescue => e
      @log.error "Failed to send events: #{e}"
      @log.error e.backtrace.join("\n")
    ensure
      @buffer = []
    end

    def handle_event(event)
      return unless @connected
      data = @handler.serialize_event event
      @connection.send_data data
    rescue => e
      @log.error "Failed to send event: #{e}"
      @log.error e.backtrace.join("\n")
    end

    def collect_events(buffer)
      buffer.pop do |event|
        handle_event event
        collect_events buffer
      end
    end

    def collect_events_buffer(buffer)
      buffer.pop do |event|
        @buffer << event
        collect_events_buffer buffer
      end
    end
  end

  class Server
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

  def self.family; :tcp; end

  def self.connect(log, opts, handler)
    raise "Missing required key :host" if (host = opts[:host]).nil?
    raise "Missing required key :port" if (port = opts[:port]).nil?
    flush_period = opts[:flush_period] || 10
    Client.new log, host, port, handler, flush_period
  end

  def self.listen(log, opts, handler, *args)
    raise "Missing required key :host" if (host = opts[:host]).nil?
    raise "Missing required key :port" if (port = opts[:port]).nil?
    Server.new log, host, port, handler, *args
  end
end
