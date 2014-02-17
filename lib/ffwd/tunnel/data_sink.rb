module FFWD::Tunnel
  class DataSink
    def initialize handle
      @handle = handle
    end

    def send_data data
      @handle.send_data data
    end
  end
end
