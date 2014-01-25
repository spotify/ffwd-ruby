module FFWD
  class Handler
    def name
      "handler"
    end

    def serialize_all events, metrics; end
    def serialize_event event; end
    def serialize_metric metric; end
  end
end
