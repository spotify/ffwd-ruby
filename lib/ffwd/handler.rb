require_relative 'connection'

module FFWD
  class Handler < FFWD::Connection
    def self.new signature, parent, *args
      instance = super(signature, *args)

      instance.instance_eval do
        @parent = parent
      end

      instance
    end

    def unbind
      @parent.unbind
    end

    def connection_completed
      @parent.connection_completed
    end

    def send_all events, metrics; end
    def send_event event; end
    def send_metric metric; end
  end
end
