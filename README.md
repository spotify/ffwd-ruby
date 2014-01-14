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
gem install
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

The tunneling protocol is described here briefly (*This should not be
considered the final product and is subject to change*)

```
*Client* -> metadata   -> *Server*
         <- config     <-
         -> datastream ->
```

All messages are sent as plaintext in a line-delimited manner (\n).

**metadata** Is a JSON Object that associated the established connection with
data about the tenant.
The read keys are *tags*, *attributes* and *host*.

**config** Is a JSON Object that describes which protocol and port combinations
the tunneling client should listen to.
The object has the following structure.

```{"bind": [["tcp", 5555], ...]}```.

**datastream** Is a uni-directional stream of messages going from the client to
the agent of the following structure.
*&lt;payload&gt;* Is the data being tunneled, endoded in *base 64*.

```<protocol> ' ' <port> ' ' <payload>```

## Terminology

**Channel** The one way to do message passing between components in EVD.
