# FastForward &#187;

[![Build Status](https://travis-ci.org/spotify/ffwd.svg?branch=master)](https://travis-ci.org/spotify/ffwd)

ffwd is a flexible event and metric forwarding agent.
It is intended to run locally on the system and receive events and metrics
through a wide set of protocols and then forward them to your database.

By running locally, it is easily available to receive pushed data from
any application or service that is running on the same system.

ffwd decorates the received data with _system-wide_ tags or attributes.
By doing this, the application generating the data becomes simpler to build,
maintain, and configure since it doesn't have to know _where_ it is running.
Only that ffwd is available on the loopback interface.

This also provides benefits for simpler protocols, like [plaintext carbon](http://graphite.readthedocs.org/en/latest/feeding-carbon.html#the-plaintext-protocol),
where this kind of information can become painful to represent in the limited
structure available.

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
* [ffwd vs. collectd](docs/vs-collectd.md)
* [JSON Reference Protocol](docs/json-protocol.md)
  &mdash; Documentation about the JSON reference protocol.
* [Protobuf Protocol](docs/protobuf-protocol.md)
  &mdash; Documentation about the protobuf protocol.
* [Statistics](docs/statistics.md) &mdash; Documentation about internally
  generated statistics.

## Usage

The simplest possible use is to install all dependencies and run it using the
supplied example configuration.

```bash
$ bundle install
$ bin/ffwd ffwd.d/basic ffwd.d/in-multi ffwd.d/out-log
```

ffwd can take and overlay multiple configuration files, you can inspect the
examples available in [./ffwd.d](/ffwd.d) and activate any of those by adding
more `<path>` arguments.

You can now send events and metrics to it using one of the enabled input
protocols.
See [./ffwd.d/in-multi](/ffwd.d/in-multi) for examples on how.

ffwd also has support for multi-tenancy where multiple clients reporting into the
same agent with different metadata.
For more information, see
[Tunneling and multi-tenancy](docs/tunneling-and-multi-tenancy.md) and the
accompanied [./ffwd.d/basic-tunnel](/ffwd.d/basic-tunnel) configuration.

## Installation

ffwd is available on rubygems so it can be installed through
[gem](https://rubygems.org) using the ```gem``` command.

```bash
$ gem install ffwd
```

### Installing plugins

ffwd uses plugins which has to be installed separately in order to use them.

You can list the plugins available on rubygems through gem.

```bash
$ gem search -r 'ffwd-*'
```

You can then install the plugin(s) you want.

```bash
$ gem install ffwd-<plugin>
```

You can check that the plugin is available to ffwd using the **--plugins**
command.

```bash
$ ffwd --plugins
Loaded Plugins:
  Plugin 'log'
    Source: from gem: ffwd-<version>
    Supports: output
    Description: ...
    Options:
      ...
  Plugin 'json'
    Source: from gem: ffwd-<version>
    Supports: input
    Description: ...
    Options:
      ...
  Plugin 'tunnel'
    Source: from gem: ffwd-tunnel-<version>
    Supports: input
    Description: ...
    Options:
      ...
...
```

At this point you will probably discover ffwd FFWD does not support your
favorite plugin.
Reading our [writing plugins guide](docs/writing-plugins.md) should enable you
to remedy this.

## Statistics

ffwd reports internal statistics allowing for an insight into what is going on.

All statistics are reported as internally generated metrics with a rich set of
tags.

For details in which statistics are available, see [the Statistics
documentation](docs/statistics.md).

## Contributing

1. Fork FastForward (or a plugin) from
   [github](https://github.com/spotify/ffwd) and clone your fork.
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

This will setup the component to listen on the default debug port (19001).

The traffic can now be sniffed with a tool like netcat.

```
$ nc localhost 19001
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

**fwc** is a [small CLI tool](lib/fwc.rb) for connecting and analyzing ffwd
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

**Core** &mdash; [The component](lib/ffwd/core.rb) in ffwd that ties
everything together.

The *core* component is also broken up into two other distinct parts to support
*virtual* cores when tunneling. These are.

* **CoreProcessor** Is responsible for running calculation engines for rates,
  histograms, etc...
* **CoreEmitter** Is responsible for emitting metrics and events, passing them
  either straight to the supplied output channel or into the supplied
  *CoreProcessor*.
