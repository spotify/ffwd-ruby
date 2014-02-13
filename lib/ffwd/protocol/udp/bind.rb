require 'eventmachine'

require_relative '../../retrier'

module FFWD::UDP
  class Bind
    def initialize core, log, host, port, handler, args, rebind_timeout
      @peer = "#{host}:#{port}"
      @c = nil

      info = "udp://#{@peer}"

      r = FFWD::Retrier.new log, core.input, rebind_timeout do |a|
        @c = EM.open_datagram_socket host, port, handler, core, *args
        log.info "Bind on #{info} (attempt #{a})"
      end

      r.error do |a, t, e|
        log.error "Failed to bind #{info} (attempt #{a}), retry in #{t}s", e
      end

      core.input.stopping do
        log.info "Unbinding #{info}"

        if @c
          @c.unbind
          @c = nil
        end
      end
    end
  end
end
