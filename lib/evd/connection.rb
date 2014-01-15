module EVD
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
