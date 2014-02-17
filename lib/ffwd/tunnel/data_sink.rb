module FFWD::Tunnel
  class DataSink
    def initialize handle
      @handle = handle
    end

    def << data
      @handle.dispatch data
    end
  end
end
