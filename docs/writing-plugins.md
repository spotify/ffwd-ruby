# Writing Plugins

This document describes how to write a plugin for FastForward.

You should
[familiarize yourself](https://github.com/eventmachine/eventmachine/wiki/Tutorials)
with [EventMachine](http://rubyeventmachine.com/) before attempting this
tutorial.

## Basic structure

The following is an example of a basic plugin that does exactly nothing.

```ruby
require 'ffwd/plugin'

module FFWD::Plugin
  module Foo
    include FFWD::Plugin
    register_plugin "foo"
  end
end
```

Adding this file to lib/ffwd/plugin/foo.rb will make FFWD automatically
discover it.

You can try this in the **ffwd-core** project and then test it with
```bin/ffwd --list-plugins```.

```bash
$ bin/ffwd --list-plugins
```

Done right this should list your newly created plugin among the list of
available plugins.

You should also note that the **supports:** block is empty.

It is now time to fix that.

### Input Plugin

An **input plugin** implements the **setup_input** method in the plugin module.

```ruby
require 'ffwd/plugin'
require 'ffwd/plugin_base'

module FFWD::Plugin
  module Foo
    # ...

    class Input < FFWD::PluginBase
    end

    def self.setup_input core, opts={}
      Input.new
    end
  end
end
```

The return value of the input plugin is expected to be *any object* that
responds to the **start** and the **stop** method.
The **start** method is expected to take two parameters.

**input** &mdash; The input channel which the plugin can send input data to.

**output** &mdash; The output channel which the plugin can send output data to.

The above example uses **FFWD::PluginBase** which provides these methods and
allows the author to simply implement the **init** method.

Lets make our plugin periodically send something on the input channel.

```ruby
require 'eventmachine'

require 'ffwd/plugin'
require 'ffwd/plugin_base'

module FFWD::Plugin
  module Foo
    # ...

    class Input < FFWD::PluginBase
      def init input, output
        timer = EM::PeriodicTimer.new(10) do
          input.metric :key => "foo", :value => 10
        end

        stopping do
          timer.cancel
        end
      end
    end

    def self.setup_input core, opts={}
      Input.new
    end
  end
end
```

With this we learn two new things.

*FastForward plugins runs inside of EventMachine*, so in order to periodically
do something we can use
[EM::PeriodicTimer](http://eventmachine.rubyforge.org/EventMachine/PeriodicTimer.html).

The **stopping** method is a benefit from using the **FFWD::PluginBase** class
as a base.
The provided block gets invoked anytime **Core** decides that our plugin should be
stopped.
*Omitting this* would cause the timer to continue firing even though an input
plugin is supposed to have been stopped which would have very strange effects.

There is nothing about our newly created plugin that is particularly
interesting, if enabled it just generated the same metric every 10 seconds.

In the next section we will talk about binding to a specified port and receive
metrics over the network using FFWD's **protocol stack**.

#### Input: Binding to a port

```ruby
require 'eventmachine'

require 'ffwd/connection'
require 'ffwd/logging'
require 'ffwd/plugin'
require 'ffwd/protocol'

module FFWD::Plugin
  module Foo
    include FFWD::Plugin
    include FFWD::Logging
    register_plugin "foo"

    class Connection < FFWD::Connection
      include FFWD::Logging
      include EM::Protocols::LineText2

      def initialize input, output, metric_key
        @input = input
        @metric_key = metric_key
      end

      def receive_line line
        @input.metric :key => @metric_key, :value => line.to_i
      rescue => e
        log.error "Failed to receive metric", e
      end
    end

    DEFAULT_PORT = 4567
    DEFAULT_METRIC_KEY = "foo"

    def self.setup_input core, opts={}
      opts[:port] ||= DEFAULT_PORT
      metric_key = opts[:metric_key] || DEFAULT_METRIC_KEY
      protocol = FFWD.parse_protocol(opts[:protocol] || "tcp")
      protocol.bind log, opts, Connection, metric_key
    end
  end
end
```

Above we have extended our example to use the FastForward **protocol stack**.
The **protocol stack** helps us perform common tasks, in this case it enables
us to bind using any supported protocol (tcp over unix socket, tcp) with little
difficulty.

The **bind** part of the **protocol stack** reads the following parameters.

* **:host**&mdash;The host to bind.
* **:port**&mdash;The port to bind.
* **:path**&mdash;The file to used when protocol is **unix+<tcp/udp>**.

We're also using **FFWD::Connection**, this is not terribly important at this
phase and you could just as well have used a regular **EM::Connection**.

The **Connection** class includes the
[EM::Protocols::LineText2](http://eventmachine.rubyforge.org/EventMachine/Protocols/LineText2.html)
helper from EventMachine which allows us to simply implement the
**receive_line** method to handle lines received in any connection.

We've also included the **FFWD::Logging** mixin, which incorporates logging
functions for both modules and classes.
Using this we can clearly communicate why and where an error was encountered.

The result is an input plugin that binds to port 4567 (default) and expect to
receive lines of metric values which will in turn be emitted with a
configurable **key**.

The **input** configuration for this plugin would look like the following.

```yaml
:input:
  - :type: "foo"
    :metric_key: "bar"
```

### Output Plugin

An **output plugin** implements the **setup_output** method in the plugin
module.

```ruby
require 'ffwd/plugin'
require 'ffwd/plugin_base'

module FFWD::Plugin
  module Foo
    # ...

    class Output < FFWD::PluginBase
    end

    def self.setup_output core, opts={}
      Output.new
    end
  end
end
```

The return value of the output plugin is expected to be very similar to the
input plugin, however it is only expected to receive a single parameter.

**output**&mdash;The output channel which this plugin should subscribe to for
events and metrics.

Lets write a plugin that logs whatever it receives.

```ruby
require 'ffwd/logging'
require 'ffwd/plugin'
require 'ffwd/plugin_base'

module FFWD::Plugin
  module Foo
    # ...

    class Output < FFWD::PluginBase
      include FFWD::Logging

      def init output
        es = output.subscribe_event do |event|
          log.info "Event: #{event}"
        end

        ms = output.subscribe_metric do |metric|
          log.info "Metric: #{metric}"
        end

        stopping do
          output.unsubscribe_event es
          output.unsubscribe_metric ms
        end
      end
    end

    def self.setup_output core, opts={}
      Output.new
    end
  end
end
```

#### Output: Connecting to a server

Lets assume that we want our plugin to be able to write the numbers that it
receives somewhere else.

If that is the case, then we expect it to implement the **setup_output**
method in the plugin module.

```ruby
require 'eventmachine'

require 'ffwd/connection'
require 'ffwd/handler'
require 'ffwd/logging'
require 'ffwd/plugin'
require 'ffwd/protocol'

module FFWD::Plugin
  module Foo
    # ...

    class Handler < FFWD::Handler
      def name
        "foo.connect"
      end

      def send_all events, metrics
        send_data (metrics.map{|m| m.metric.to_s}.join('\n') + "\n")
      end

      def send_metric metric
        send_data (metric.to_s + "\n")
      end
    end

    def self.setup_input core, opts={}
      instance = ConnectHandler.new
      protocol.connect log, opts, instance
    end
  end
end
```

Implementing the output part of a plugin on the **protocol stack** is slightly
different.
You are expected to provide a **FFWD::Handler** implementation, which can
implement the **send_all**, **send_event** and **send_metric** methods.

The **connect** part of the **protocol stack** reads the following parameters.

* **:host**&mdash;The host to connect to.
* **:port**&mdash;The port to connect to.
* **:flush_period**&mdash;If set, causes the connection to buffer messages, and
  only flush at the specified period (in seconds) using **send_all**.
  Otherwise will send each message as they arrive, calling **send_event**
  and **send_metric** respectively.
  If the buffer has not been successfully flushed during the specified period,
  the next buffer will be dropped.
* **:outbound_limit**&mdash;The allowed number of bytes that are allowed to be
  in the buffer used for the outbound TCP buffer.
  If this is full, incoming events and metrics will be dropped.

The **output** configuration for this plugin would look like the following.

```yaml
:output:
  - :type: "foo"
    :host: "example.com"
    :port: 4567
    :flush_period: 10
    :outbound_limit: 10000
```
