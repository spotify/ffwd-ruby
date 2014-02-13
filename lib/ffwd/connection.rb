require 'eventmachine'

module FFWD
  # Connections are used by input plugins in the protocol stack.
  #
  # The sole purpose this exists is to incorporate a datasink functionality
  # in the EM::Connection.
  #
  # The datasink is used by tunnels to 'hook into' outgoing data.
  class Connection < EM::Connection
    def datasink= sink
      @datasink = sink
    end

    # send_data indirection.
    def send_data data
      if @datasink
        @datasink << data
        return
      end

      super data
    end
  end
end
