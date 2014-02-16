require 'eventmachine'

require_relative '../../reporter'
require_relative '../../retrier'

module FFWD::UDP
  class Bind
    include FFWD::Reporter

    setup_reporter :keys => [
      :received_events, :received_metrics,
      :failed_events, :failed_metrics
    ]

    attr_reader :reporter_meta

    def initialize core, log, host, port, connection, args, rebind_timeout
      @peer = "#{host}:#{port}"
      @reporter_meta = {
        :type => connection.plugin_type,
        :listen => @peer, :family => 'udp'
      }

      @sig = nil

      info = "udp://#{@peer}"

      r = FFWD.retry :timeout => rebind_timeout do |a|
        @sig = EM.open_datagram_socket host, port, connection, self, core, *args
        log.info "Bind on #{info} (attempt #{a})"
      end

      r.error do |a, t, e|
        log.error "Failed to bind #{info} (attempt #{a}), retry in #{t}s", e
      end

      r.depend_on core

      core.stopping do
        log.info "Unbinding #{info}"

        if @sig
          @sig.unbind
          @sig = nil
        end
      end
    end
  end
end
