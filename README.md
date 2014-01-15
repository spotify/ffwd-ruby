# evd

A local event and metrics collection daemon prototype.

EVD is an event agent prototype meant to run on a single host and receive
metrics and events using a set of standard protocols.

It acts as an abstraction layer between between a service and monitor system,
it is capable of rich metadata decoration of the events passing through it.

## Usage

The simplest possible use is to install all dependencies and run it using the
supplied example configuration.

```
bundle install
bin/evd -c docs/example.yaml
```

This will start up an instance that periodically reports statistics about
itself.

You can try out it's capabilities by running the supplied docs/client.rb.

```
ruby docs/client.rb
```

Or it's multitenant tunneling capabilities using docs/tunnel.txt

```
nc localhost 9000 < docs/tunnel.txt
```

## Tunneling

EVD has prototype support for tunneling traffic for multitenant system using
the *tunnel* plugin.

*The tunneling protocol is experimental and will be subject to change*

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
The read keys are *bind* which should be an array of bind configurations.

```{"bind": [{"protocol": "tcp", "port": 5555}, ...]}```.

**datastream** Is a bi-directional stream of messages going from the client to
the agent of the following structure.
*&lt;base64-payload&gt;* Is the data being tunneled, encoded in *base 64*.

```<protocol> ' ' <port> ' ' <addr> ':' <port> <base64-payload>```

**protocol** is the protocol of the data stream (tcp or udp).

**port** is the port that was bound.

**addr** is the remote ip of the connected peer.

**port** is the remote port of the connected peer.

## Terminology

**Channel** The one way to do message passing between components in EVD.
