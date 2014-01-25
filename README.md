# Spotify FastForward &#9193;

A highly flexible, multi-protocol events and metrics forwarder capable of
merging and decorating events and metrics from a number of sources and
multiplexing them to number of event and metric consumers.

FFWD is a deamon meant to run on a single host and receive metrics and events
using a set of standard protocols.
It is a single point of entry for any service to dispatch data in any protocol
that happens to suit them with a simple endpoint.

*FFWD is currently a prototype implemented to explore this design.
Your milage might vary.*

* [Usage](#usage)
* [Writing Plugins](#writing-plugins)
* [Events and Metrics](#events-and-metrics)
  * [Input Data Structure](#input-data-structure)
  * [Output Data Structure](#output-data-structure)
* [Debugging](#debugging)
* [Terminology](#terminology)

Other topics:
* [FFWD vs. collectd](docs/vs-collectd.md)
* [Tunneling and multi-tenancy](docs/tunneling-and-multi-tenancy.md)

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
E.g. the carbon protocol or the JSON-line protocol (requires
[ffwd-carbon](https://github.com/spotify-ffwd/ffwd-carbon)):

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

## Writing plugins

**TODO (parmus)**

## Events and Metrics

The two types of *data* that FFWD processes are *events* and *metrics*.

An input plugin is responsible for consuming *data* and **emit** it into
*Core*.
In contrast, an output plugin **consumes** *data* from *Core* and forwards it.

Two types of *data* are understood by FFWD.

* **events** Which are passed as-is, without being processed.
* **metrics** Which are optionally processed (if the **:proc** field is
  present), but default to being passed as-is.

*Core* also makes a distinction between **input** and **output** data.

*Core* is responsible for *decorating* both events and metrics with *metadata*
by adding *tags* and *attributes*.

These are both heavily inspired by the fields present in
[riemann](http://riemann.io/concepts.html) and
[collectd](http://collectd.org/).

For the schemas of both input and output data types, see
[lib/ffwd/event.rb](lib/ffwd/event.rb) and
[lib/ffwd/metric.rb](lib/ffwd/metric.rb).

### Input Data Structure

The following section describes the structure of *input data*.

**input data** is a hash either classified as an **event** or as a **metric**.

These hashes contain the following fields.

The following are the keywords and their meaning used on each field.

* **optional**&nbsp;Field is not required to be provided by an *input* plugin.
* **internal**&nbsp;Field is used for internal purposes and should not be
  provided by an *input plugin* and will be ignored if it is.
* **event only**&nbsp;Field will only be read if an *event* is emitted.
* **metric only**&nbsp;Field will only be read if a *metric* is emitted.

*Note: In this section, 'data' refers to both events and metrics.*

**:key**<br />
&emsp;The key of the *data*.<br />
**:value**<br />
&emsp;A numeric value of the *data*.<br />
**:time (optional)**<br />
&emsp;The time of when the *data* was received, if not set will be set to the
current time by *Core*.<br />
**:ttl (optional, event only)**<br />
&emsp;The amount of time an event is considered *valid*.<br />
**:state (optional, event only)**<br />
&emsp;Is used to communicate the state of the event, like **ok** or
**critical**.<br />
**:description (optional, event only)**<br />
&emsp;A description of the event.<br />
**:host (optional, metadata)**<br />
&emsp;The host which is the originator of the data, if not set will be added by
*Core*.<br />
**:tags (optional, metadata)**<br />
&emsp;Tags to associate with the event, will be merged by any tags configured
in *Core*.<br />
**:attributes (optional, metadata)**<br />
&emsp;Attributes to associate with the event, will be merged by any attributes
configured in **Core**.<br />
**:source**<br />
&emsp;If *data* is the result of some processing, this is the *source key* of
the data that caused it.<br />
**:proc (optional, metric only)**<br />
&emsp;The processor to use for metrics.<br />

It is designed like this to allow for input plugins to provide data in a
*terse* format, making it easier for author to write plugins. See [the
statsd plugin](lib/ffwd/plugin/statsd.rb) for a good example where only
**:key**, **:value** and **:proc** is used.

### Output Data Structure

After *data* has been emitted by a plugin, processed by *Core*, it is then
converted into a *Struct* and treated as **output** (see
[MetricEmitter](lib/ffwd/metric_emitter.rb) and
[EventEmitter](lib/ffwd/event_emitter.rb)).

This causes the events and metrics to be *consistent* and more type safe when
it reaches and *output plugin*.
The *output data* is then converted by the output plugin to suit whatever
the target protocol requires.

An *output plugin* can and often will omit fields which cannot be sanely
converted to the target protocol.
Instead it is up to the system administrator to choose an output scheme which
match their requirements.

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
