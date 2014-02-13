module FFWD::TCP
  class ConnectBase
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
      @reconnect_timer = nil
      @reconnect_timeout = INITIAL_TIMEOUT
      @reporter_id =  "#{@handler.name}/#{peer}"

      @c = nil
      @open = false
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

    def connect
      @c = EM.connect @host, @port, @handler, self, *@args
    end

    def disconnect
      @closing = true
      @c.close_connection
    end

    def connection_completed
      @open = true
      @log.info "Connected tcp://#{peer}"
      @reconnect_timeout = INITIAL_TIMEOUT

      unless @reconnect_timer.nil?
        @reconnect_timer.cancel
        @reconnect_timer = nil
      end
    end

    def unbind
      @open = false

      if @closing
        @log.info "Closing connection to tcp://#{peer}"
        return
      end

      @log.info "Disconnected from tcp://#{peer}, reconnecting in #{@reconnect_timeout}s"

      unless @reconnect_timer.nil?
        @reconnect_timer.cancel
        @reconnect_timer = nil
      end

      @reconnect_timer = EM::Timer.new(@reconnect_timeout) do
        @reconnect_timeout *= 2
        @reconnect_timer = nil
        @c = EM.connect @host, @port, @handler, self, *@args
      end
    end

    def connected?
      @open
    end

    # Check if a connection is writable or not.
    def writable?
      connected? and @c.get_outbound_data_size < @outbound_limit
    end
  end
end
