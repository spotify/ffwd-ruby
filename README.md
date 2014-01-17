# evd

A local event and metrics collection daemon prototype.

EVD is an event agent prototype meant to run on a single host and receive
metrics and events using a set of standard protocols.

It acts as an abstraction layer between between a service and monitor system,
it is capable of rich metadata decoration of the events passing through it.

* [Usage](#usage)
* [Events and Metrics](#events-and-metrics)
* [Debugging](#debugging)
* [Tunneling and multi-tenancy](#tunneling-and-multi-tenancy)
* [Terminology](#terminology)

## Usage

The simplest possible use is to install all dependencies and run it using the
supplied example configuration.

```
bundle install
bin/evd -c docs/simple.conf
```

This will start up an instance that periodically reports statistics about
itself.

You can try out it's capabilities by running the supplied
[docs/client-test.rb](docs/client-test.rb).

```
ruby docs/client-test.rb
```

If you want to experiment with multitenancy, use the provided
[docs/tunnel.conf](docs/tunnel.conf) as base.
For the example [docs/client-test.rb](docs/client-test.rb) to work, you have to
start a tunneling agent.

You can do this by running the provided [bin/tunnel-agent](bin/tunnel-agent)
which is a reference implementation of the [tunneling
protocol](#tunneling-and-multi-tenancy).

```
$ bin/tunnel-agent
INFO:__main__:connected
INFO:__main__:CONFIG: {...}
...
```

It should now be possible to use the provided
[docs/client-test.rb](docs/client-test.rb) the same way as you did before.

## Events and Metrics

The two types of data that EVD processes are *events* and *metrics*.

An input or output plugin can both produce and consume *events* and *metrics*,
but they are treated slightly differently by *Core*.

* **events** Are passed as-is, without being processed.
* **metrics** Can be optionally processed, but default to being passed as-is.

*Core* is also responsible for *decorating* both events and metrics with
*metadata* by adding *tags* and *attributes*.

*An output plugin does not* have to support forwarding this *metadata* and in
fact most do not.
Instead it is up to the system administrator to choose a suitable output
scheme.

*Core* makes a distinction between an **input event/metric** and an **output
event/metric**.

An **input** type of data is just a Hash with keyword fields and values.
It is designed like this to allow for input plugins to provide *terse*
information like only the *:key* and *:value* fields of a metric (see [the
statsd plugin](lib/evd/plugin/statsd.rb) for a good example).

An **output** type of data is in contrast defined by a Struct.
This is because we want the metrics and events to be *consistent* after they
have passed through *Core* and reaches an output plugin.

For the schemas of both input and output data types, see
[lib/evd/event.rb](lib/evd/event.rb) and
[lib/evd/metric.rb](lib/evd/metric.rb).

## Debugging

While the agent is running, it is possible to sniff all internal input and
output channels by enabling the debug component.

This is done by adding the following to your evd configuration.

```
:debug: {}
```

This will setup the component to listen on the default debug port (9999).

The traffic can now be sniffed with a tool like netcat.

```
$ nc localhost 9999
{"id":"core.output","type":"event","data": ...}
{"id":"tunnel.input/127.0.0.1:55606","type":"event","data": ...}
{"id":"core.output","type":"event","data": ...}
{"id":"tunnel.input/127.0.0.1:55606","type":"event","data": ...}
{"id":"tunnel.input/127.0.0.1:55606","type":"metric","data": ...}
...
```

Each line consists of a JSON object with the following fields.

**id** The id that the specified events can be grouped by, this indicates
which channel the traffic was sniffed of.

**type** The type of the *data* field.

**data** Data describing the sniffed event according to specified *type*.

## Tunneling and multi-tenancy

EVD has prototype support for tunneling traffic for multitenant system using
the *tunnel* plugin.

**The tunneling protocol is experimental and will be subject to future change**

```
*Client* -> metadata   -> *Server*
         <- config     <-
         -> datastream ->
         <- datastream <-
```

All messages are sent as plaintext in a line-delimited manner (\n).

**metadata** Is a JSON Object that associated the established connection with
data about the tenant.
The read keys are *tags*, *attributes* and *host*.

```{"tags": ["env::production", ...], "attributes": {"site": "sto"}, "host": "tenant-1"}```

**config** Is a JSON Object that describes which *protocol and port* combinations
the tunneling client should bind to and tunnel traffic from.
The read keys are *input* which should be an array of input configurations.

```{"input": [{"protocol": "tcp", "port": 5555}, ...]}```.

**datastream** Is a bi-directional stream of messages going from the client to
the agent of the following structure.
*&lt;base64-payload&gt;* Is the data being tunneled, encoded in *base 64*.

```<protocol> ' ' <port> ' ' <addr> ':' <port> <base64-payload>```

**protocol** is the protocol of the data stream (tcp or udp).

**port** is the port that was bound.

**addr** is the remote ip of the connected peer.

**port** is the remote port of the connected peer.

## Terminology

**Channel** &mdash; [The one way](lib/evd/channel.rb) to do synchronous message
passing between components.

**PluginChannel** &mdash; [An abstraction](lib/evd/plugin_channel.rb) on top of
two *Channel*'s, one dedicated to *metrics*, the other one to *events*.

**Core** &mdash; [The component](lib/evd/core.rb) in EVD that ties everything
together.

The *core* component is also broken up into two other distinct parts to support
*virtual* cores when tunneling. These are.

* **CoreProcessor** Is responsible for running calculation engines for rates,
  histograms, etc...
* **CoreEmitter** Is responsible for emitting metrics and events, passing them
  either straight to the supplied output channel or into the supplied
  *CoreProcessor*.
