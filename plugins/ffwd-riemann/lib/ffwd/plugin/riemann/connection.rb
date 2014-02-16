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

    def initialize bind, core, log
      @bind = bind
      @core = core
      @log = log
    end

    def receive_object(m)
      unless m.events.nil? or m.events.empty?
        events = m.events.map{|e| read_event(e)}
        events.each{|e| @core.input.event e}
      end

      @bind.increment :received_events, m.events.size
      send_ok
    rescue => e
      @bind.increment :failed_events, m.events.size
      @log.error "Failed to receive object", e
      send_error e
    end

    protected

    def send_ok; end
    def send_error(e); end
  end
end
