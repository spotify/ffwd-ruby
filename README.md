# FastForward &#9193;

A highly flexible, multi-protocol events and metrics forwarder capable of
merging and decorating events and metrics from a number of sources and
multiplexing them to number of event and metric consumers.

FFWD is a deamon meant to run on a single host and receive metrics and events
using a set of standard protocols.
It is a single point of entry for any service to dispatch data in any protocol
that happens to suit them with a simple endpoint.

*FFWD is currently a prototype implemented to explore this design.
Your mileage might vary.*

* [Usage](#usage)
* [Installation](#installation)
  * [Installing Plugins](#installing-plugins)
* [Contributing](#contributing)
* [Debugging](#debugging)
* [Terminology](#terminology)

Other focused topics.
* [Tunneling and multi-tenancy](docs/tunneling-and-multi-tenancy.md)
* [Writing Plugins](docs/writing-plugins.md)
* [Events and Metrics](docs/events-and-metrics.md)
  * [Input Data Structure](docs/events-and-metrics.md#input-data-structure)
  * [Output Data Structure](docs/events-and-metrics.md#output-data-structure)
* [Schemas](docs/schemas.md)
* [FFWD vs. collectd](docs/vs-collectd.md)
* [FFWD vs. Language X](docs/vs-language-x.md)

## Usage

The simplest possible use is to install all dependencies and run it using the
supplied example configuration.

```bash
$ bundle install
$ bin/ffwd -c docs/simple.conf
```

This will start up an instance that periodically reports statistics about
itself.

You can now send events and metrics to it using one of the enabled input
protocols.

E.g. the carbon protocol (requires [ffwd-carbon](/plugins/ffwd-carbon)) or the
built-in reference [JSON-line protocol](/lib/ffwd/plugin/json_line.rb).

```bash
$ echo "random.diceroll 4  `date +%s`" | nc -q0 localhost 2003
$ echo '{"type": "metric", "key": "random.diceroll", "value": 6}' | nc -q0 localhost 3000
```

You can try out more advanced protocols using the supplied sample client:
[docs/client-test.rb](docs/client-test.rb).

```bash
$ ruby docs/client-test.rb
```

If you have the log output plugin enabled, you should see these metrics written
to the log.

FFWD has support for multi-tenancy (multiple guests reporting into the same
FFWD agent).
For more information, see
[Tunneling and multi-tenancy](docs/tunneling-and-multi-tenancy.md)

## Installation

FFWD is available on rubygems so it can be installed through
[gem](https://rubygems.org).

```bash
$ gem install ffwd-core
```

### Installing plugins

FFWD uses plugins which has to be installed separately in order to use them.

You can list the plugins available on rubygems through gem.

```bash
$ gem search -r 'ffwd-*'
```

You can then install the plugin(s) you want.

```bash
$ gem install ffwd-<plugin>
```

You can check that the plugin is available to FFWD using the **--list-plugins**
command.

```bash
$ ffwd --list-plugins
Available Plugins:
Plugin 'log' (from gem: ffwd-core-<version>)
  supports: output
Plugin 'json_line' (from gem: ffwd-core-<version>)
  supports: input
Plugin 'tunnel' (from gem: ffwd-tunnel-<version>)
  supports: input
...
```

At this point you will probably discover that FFWD does not support your
favorite plugin.
Reading our [writing plugins guide](docs/writing-plugins.md) should enable you
to remedy this.

## Contributing

1. Fork FastForward (or a plugin) from
   [github](https://github.com/spotify-ffwd) and clone your fork.
2. Hack.
3. Verify code by running any existing test-suite; ```bundle exec rspec```.
   Try to include tests for your changes.
4. Push the branch back to GitHub.
5. Send a pull request to our upstream repo.

## Debugging

While the agent is running, it is possible to sniff all internal input and
output channels by enabling the debug component.

This is done by adding the following to your ffwd configuration.

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

*As an alternative to connecting directly to the debug socket, you can also use
the [**fwc**](#debugging-with-fwc) tool*.

Each line consists of a JSON object with the following fields.

**id** The id that the specified events can be grouped by, this indicates
which channel the traffic was sniffed of.

**type** The type of the *data* field.

**data** Data describing the sniffed event according to specified *type*.

### Debugging with fwc

**fwc** is a [small CLI tool](lib/fwc.rb) for connecting and analyzing FFWD
debug data.

It can be invoked with the **--raw** and/or **--summary** switch.

**--raw** will output everything received on the debug socket, but will also
attempt to throttle the output to protect the users terminal.

**--summary** will only output a summary of *what has been seen* on the various
channels.

The output will look something like the following.

```
<time> INFO: Summary Report:
<time> INFO:   core.input (event)
<time> INFO:     event-foo 2
1time> INFO:     event-bar 2
1time> INFO:   core.output (event)
1time> INFO:     event-foo 2
1time> INFO:     event-bar 2
```

The above says that the **core.input** channel has passed two events with the
keys **event-foo** and **event-bar**.

Similarly the **core.output** channel has passed the same set of events,
meaning that all of the events are expected to have been processed by output
plugins.

## Terminology

**Channel** &mdash; [The one way](lib/ffwd/channel.rb) to do synchronous
message passing between components.

**PluginChannel** &mdash; [An abstraction](lib/ffwd/plugin_channel.rb) on
top of two *Channel*'s, one dedicated to *metrics*, the other one to *events*.

**Core** &mdash; [The component](lib/ffwd/core.rb) in FFWD that ties
everything together.

The *core* component is also broken up into two other distinct parts to support
*virtual* cores when tunneling. These are.

* **CoreProcessor** Is responsible for running calculation engines for rates,
  histograms, etc...
* **CoreEmitter** Is responsible for emitting metrics and events, passing them
  either straight to the supplied output channel or into the supplied
  *CoreProcessor*.
