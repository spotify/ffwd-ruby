module FFWD::TCP
  class Connection
    INITIAL_TIMEOUT = 2

    attr_reader :log, :peer, :reporter_id

    def initialize log, host, port, handler, args, outbound_limit
      @log = log
      @host = host
      @port = port
      @handler = handler
      @args = args
      @outbound_limit = outbound_limit

      @peer = "#{host}:#{port}"
      @closing = false
      @reconnect_timeout = INITIAL_TIMEOUT
      @reporter_id =  "#{@handler.name}/#{peer}"

      @timer = nil
      @c = nil
      @open = false
    end

    # Start attempting to connect.
    def connect
      log.info "Connecting to tcp://#{@host}:#{@port}"
      @c = EM.connect @host, @port, @handler, self, *@args
    end

    # Explicitly disconnect and discard any reconnect attempts..
    def disconnect
      log.info "Disconnecting from tcp://#{@host}:#{@port}"
      @closing = true

      @c.close_connection if @c
      @timer.cancel if @timer
      @c = nil
      @timer = nil
    end

    def send_event event
      @c.send_event event
    end

    def send_metric metric
      @c.send_metric metric
    end

    def send_all events, metrics
      @c.send_all events, metrics
    end

    def connection_completed
      @open = true
      @log.info "Connected tcp://#{peer}"
      @reconnect_timeout = INITIAL_TIMEOUT

      unless @timer.nil?
        @timer.cancel
        @timer = nil
      end
    end

    def unbind
      @open = false
      @c = nil

      if @closing
        return
      end

      @log.info "Disconnected from tcp://#{peer}, reconnecting in #{@reconnect_timeout}s"

      unless @timer.nil?
        @timer.cancel
        @timer = nil
      end

      @timer = EM::Timer.new(@reconnect_timeout) do
        @reconnect_timeout *= 2
        @timer = nil
        @c = EM.connect @host, @port, @handler, self, *@args
      end
    end

    # Check if a connection is writable or not.
    def writable?
      not @c.nil? and @open and @c.get_outbound_data_size < @outbound_limit
    end
  end
end
