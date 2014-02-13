require_relative 'shared'

module FFWD::Plugin::Riemann
  module Output
    def send_all events, metrics
      all_events = []
      all_events += events.map{|e| make_event e} unless events.empty?
      all_events += metrics.map{|m| make_metric m} unless metrics.empty?
      return if all_events.empty?
      m = make_message :events => all_events
      send_data encode(m)
    end

    def send_event event
      e = make_event event
      m = make_message :events => [e]
      send_data encode(m)
    end

    def send_metric metric
      e = make_metric metric
      m = make_message :events => [e]
      send_data encode(m)
    end

    def receive_data data
      message = read_message data
      return if message.ok
      @bad_acks = (@bad_acks || 0) + 1
    end
  end
end

