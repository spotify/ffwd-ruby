require_relative '../../reporter'

module FFWD::UDP
  class Connect
    include FFWD::Reporter

    set_reporter_keys :dropped_events, :dropped_metrics,
                      :sent_events, :sent_metrics

    def initialize output, log, host, port, handler
      @log = log
      @host = host
      @port = port
      @handler = handler

      @bind_host = "0.0.0.0"
      @host_ip = nil
      @c = nil
      @peer = "#{host}:#{port}"
      @reporter_id = "#{@handler.name}/#{@peer}"

      output.starting do
        @host_ip = resolve_host_ip @host

        if @host_ip.nil?
          @log.error "Could not resolve '#{@host}'"
          return
        end

        @log.info "Resolved server as #{@host_ip}"

        @c = EM.open_datagram_socket(@bind_host, nil)

        event_sub = output.event_subscribe{|e| handle_event e}
        metric_sub = output.metric_subscribe{|m| handle_metric m}

        output.stopping do
          @c.close
          output.event_unsubscribe event_sub
          output.metric_unsubscribe metric_sub
        end
      end
    end

    private

    def handle_event event
      unless @c
        increment :dropped_events, 1
        return
      end

      data = @handler.serialize_event event
      @c.send_datagram data, @host_ip, @port
      increment :sent_events, 1
    end

    def handle_metric metric
      unless @c
        increment :dropped_metrics, 1
        return
      end

      data = @handler.serialize_metric metric
      @c.send_datagram data, @host_ip, @port
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
end
