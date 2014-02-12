module FFWD::Plugin::Riemann
  module Connection
    module Serializer
      def self.dump(m)
        m.encode.to_s
      end

      def self.load(data)
        ::Riemann::Message.decode(data)
      end
    end

    def serializer
      FFWD::Plugin::Riemann::Connection::Serializer
    end

    def initialize core, log
      @core = core
      @log = log
    end

    def receive_object(m)
      unless m.events.nil? or m.events.empty?
        m.events.each do |e|
          @core.input.event read_event(e)
        end
      end

      send_ok
    rescue => e
      @log.error "Failed to receive object", e
      send_error e
    end

    protected

    def send_ok; end
    def send_error(e); end
  end
end
