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
    events = []
    events += events.map{|e| make_event e} unless events.empty?
    events += metrics.map{|m| make_metric m} unless events.empty?
    m = make_message :events => events
    encode m
  end

  def serialize_event event
    e = make_event event
    m = make_message :events => [e]
    encode m
  end

  def serialize_metric m
    e = make_event m
    m = make_message :events => [e]
    encode m
  end
end

