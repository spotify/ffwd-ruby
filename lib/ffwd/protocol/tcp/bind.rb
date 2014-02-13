require 'eventmachine'

require_relative '../../retrier'

module FFWD::TCP
  class Bind
    def initialize core, log, host, port, handler, args, rebind_timeout
      @peer = "#{host}:#{port}"
      @sig = nil

      info = "tcp://#{@peer}"

      r = FFWD::Retrier.new log, core.input, rebind_timeout do |a|
        @sig = EM.start_server host, port, handler, core, *args
        log.info "Bind on #{info} (attempt #{a})"
      end

      r.error do |a, t, e|
        log.error "Failed to bind #{info} (attempt #{a}), retry in #{t}s", e
      end

      core.input.stopping do
        log.info "Unbinding #{info}"

        if @sig
          EM.stop_server @sig
          @sig = nil
        end
      end
    end
  end
end
