def riemann
  require 'riemann/client'

  # Create a client. Host, port and timeout are optional.
  c = Riemann::Client.new :host => 'localhost', :port => 5555, :timeout => 5

  # Send a simple event
  c.tcp << {:service => 'testing', :metric => 2.5}

  # Or a more complex one
  c.tcp << {
    :host => 'web3',
    :service => 'api latency',
    :state => 'warn',
    :metric => 63.5,
    :description => "63.5 milliseconds per request",
    :time => Time.now.to_i - 10,
    :tags => ['ok', 'here'],
    :ok => "here",
  }
end

def statsd
  require 'statsd'

  s = Statsd.new('localhost')
  s.timing "hello", 1000 * rand
  s.timing "hello", 1000 * rand
  s.timing "hello", 1000 * rand
  s.timing "hello", 1000 * rand
  s.timing "hello", 1000 * rand
  s.timing "hello", 1000 * rand
  s.timing "hello", 1000 * rand
  s.timing "hello", 1000 * rand
  s.timing "hello", 1000 * rand
  s.timing "hello", 1000 * rand
  s.timing "hello", 1000 * rand
  s.timing "hello", 1000 * rand
  s.timing "hello", 1000 * rand
  s.timing "hello", 1000 * rand
  s.timing "hello", 1000 * rand
  s.timing "hello", 1000 * rand
  s.timing "hello", 1000 * rand
  s.timing "hello", 1000 * rand
  s.timing "hello", 1000 * rand
  s.timing "hello", 1000 * rand
  s.timing "hello", 1000 * rand
end

riemann
#statsd
