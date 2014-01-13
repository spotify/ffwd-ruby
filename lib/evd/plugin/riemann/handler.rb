module EVD::Plugin::Riemann::Handler
  def setup_handler
    @bad_acks = 0
  end

  def receive_data data
    message = read_message data
    return if message.ok
    @bad_acks += 1
  end

  def serialize_all events, metrics
    all_events = []
    all_events += events.map{|e| make_event e} unless events.empty?
    all_events += metrics.map{|m| make_metric m} unless metrics.empty?
    m = make_message :events => all_events
    encode m
  end

  def serialize_event event
    e = make_event event
    m = make_message :events => [e]
    encode m
  end

  def serialize_metric metric
    e = make_metric metric
    m = make_message :events => [e]
    encode m
  end
end

