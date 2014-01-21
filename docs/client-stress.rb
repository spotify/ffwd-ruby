def riemann
  require 'riemann/client'

  # Create a client. Host, port and timeout are optional.
  c = Riemann::Client.new :timeout => 5

  while true
    # Or a more complex one
    c.tcp << {
      :host => 'web3',
      :service => 'riemann/test',
      :state => 'ok',
      :metric => 63.5,
      :description => "63.5 milliseconds per request",
      :tags => ['ok', 'here'],
      :ok => "here",
    }
  end
end

def statsd
  require 'statsd'

  s = Statsd.new
  while true
    s.timing "statsd/test", 1000 * rand
  end
end

#riemann
statsd
