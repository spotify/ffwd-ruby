# FastForward Java

This is a Java implementation of FastForward.

# TODO

## Output Plugins

* Outgoing connections.
  * Need to be able to reconnect (with back-off)
  * Retain unsent data.
    * Temporary slowdowns should not cause drops.
    * Some protocols prefer batches for performance reasons.
    * On disk serialization similar to kafka?

## On-disk serialization (maybe)

Serialize centrally in _OutputManager_ to a log file.

Log files consists of sized chunks distinctly smaller than a given size, and
are named according to the following scheme:

```
queue-########.log
```

Incoming events and metrics are written to the log file serially.
After they have been written they are dispatched to all sinks, this will
include the message and the offset in the log that they have.
Each output plugin keeps track of which offset they are sending and retains a
reference to the corresponding log file that the offset belongs to.

A scheduled process scans all log files in order, if a file has zero references
it will be unlinked.
It also writes all the output plugins and their corresponding offsets to a
state file so that they can be restored at a later point in time.
The id of an output plugin must be explicitly set in the configuration file so
that offsets can be recorded and restored.

Each log file contains the following structures:

```
magic    | 4 | 4 byte magic, making up "FFLG" (0x46 0x46 0x4c 0x47) in ASCII.
version  | 2 | Unsigned 2-byte short, indicating the current version of the log
               format.
offset   | 8 | Unsigned offset in number of messages that is the start of this
               log
...
header   | 4 | An unsigned integer, where the first bit indicates:
                - 0 for a metric
                - 1 for an event.
               The other 31 bits indicates the size of the log entry, giving a
               maximum of 2^31 (2147483648) bytes.
... other entries until EOF.
```

## Riemann
* Input plugin
* Output plugin
  * Make batch size configurable.
  * Allow multiple simultaneous batches (tracked by ack's), make this
    configurable.

## Kafka

* Output plugin
  * Very high level, take care to implement back-off and assert (somehow)
    that date is being sent.

## collectd

* Input plugin, see
  [ruby implementation](https://github.com/spotify/ffwd/blob/master/plugins/ffwd-collectd/lib/ffwd/plugin/collectd/parser.rb)
  for details on how to decode frames.

## Debug protocol
Allow connections to 'sniff' what is going on internally, make sure to follow
the previous protocol to allow existing clients to keep working until
replacements can be built.

Message structure is:

```json
{"id": "identifier", "type": "'metric' or 'event'", "data": {}}
```

## Instrumentation

* On a per input plugin basis.
  * Measure errors.
  * Measure dropped events/metrics.
  * Measure failed events/metrics.
  * Measure received events/metrics.
* On an application basis.
  * Measure events.
  * Measure metrics.
* On a per output plugin basis.
  * Measure sent events/metrics.
  * Measure dropped events/metrics.
  * Measure queue time in ms for events/messages.
  * Measure queue size and rate-of-growth for events/messages.

# Components

# Module

A module is a loadable component that extends the functionality of FastForward.
When a module is loaded it typically registers a set of plugins.

# Plugin

Either an input, or an output plugin.

This provides the implementation to read, or send data from the agent.
A plugin can have multiple _instances_ with different configurations (like
which port to listen to).

### Early Injector

The early injector is setup by AgentCore and is intended to provide the basic
facilities to perform module setup.

The following is a list of components that are given access to and their
purpose.

* _com.spotify.ffwd.module.PluginContext_
  Register input and output plugins.
* _com.fasterxml.jackson.databind.ObjectMapper (application/yaml+config)_
  ObjectMapper used to parse provided configuration file.

### Primary Injector

The primary injector contains the dependencies which are available after
modules have been registered and the initial bootstrap is done.

It contains all the components of the early injector, with the following
additions.

* _eu.toolchain.async.AsyncFramework_ - Framework implementation to use for
  async operations.
* _io.netty.channel.EventLoopGroup (boss)_ Event loop group used for boss
  threads in ServerBootstrap's.
* _io.netty.channel.EventLoopGroup (worker)_ Event loop group used for
  worker threads in {Server}Bootstrap's.
* _com.spotify.ffwd.protocol.ProtocolServers_ - Framework for setting up
  servers in a simple manner.
* _com.spotify.ffwd.protocol.ProtocolClients_ - Framework for setting up
  clients in a simple manner.
* _com.spotify.ffwd.protocol.ChannelUtils_ - Utility functions for simplyfing
  channel operations.
* _io.netty.util.Timer_ - A timer implementation.
* _com.fasterxml.jackson.databind.ObjectMapper (application/json)_
  Used to decode/encode JSON.
