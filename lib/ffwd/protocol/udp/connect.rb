require_relative '../../reporter'
require_relative '../../retrier'

module FFWD::UDP
  class Connect
    include FFWD::Reporter

    attr_reader :reporter_meta, :log

    setup_reporter :keys => [
      :dropped_events, :dropped_metrics,
      :sent_events, :sent_metrics
    ]

    def initialize core, log, host, port, handler
      @log = log
      @host = host
      @port = port
      @handler = handler

      @bind_host = "0.0.0.0"
      @host_ip = nil
      @c = nil
      @peer = "#{host}:#{port}"
      @reporter_meta = {
        :type => @handler.name, :peer => peer
      }

      info = "udp://#{@peer}"

      subs = []

      r = FFWD.retry :timeout => resolve_timeout do |a|
        unless @host_ip
          @host_ip = resolve_ip @host
          raise "Could not resolve: #{@host}" if @host_ip.nil?
        end

        @c = EM.open_datagram_socket(@bind_host, nil)
        log.info "Setup of output to #{info} successful"

        subs << core.output.event_subscribe{|e| handle_event e}
        subs << core.output.metric_subscribe{|m| handle_metric m}
      end

      r.error do |a, t, e|
        log.error "Setup of output to #{info} failed (attempt #{a}), retry in #{t}s", e
      end

      r.depend_on core

      core.stopping do
        if @c
          @c.close
          @c = nil
        end

        subs.each(&:unsubscribe).clear
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

    def resolve_ip host
      Socket.getaddrinfo(@host, nil, nil, :DGRAM).each do |item|
        next if item[0] != "AF_INET"
        return item[3]
      end

      return nil
    end
  end
end
