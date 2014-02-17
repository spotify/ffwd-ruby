# Tunneling and multi-tenancy

**The tunneling protocol is currently experimental and will be subject to
future change**

**TODO(parmus): Rewrite with focus on the container use-case **

Multi-tenancy is the act of supporting multiple distinct client services with
unique metadata (host, tags, attributes) on a single FFWD agent.

This is currently achieved with the *tunnel* plugin.

## Usage

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

## Description

In multi-tenancy we distinguish betweeh the *host* and the *guest* system.

In FFWD, the *host* system runs the FFWD agent, and every *guest* runs a
small [*tunneling agent*](bin/tunnel-agent) which connects to the *host*.

The tunneling agent is responsible for doing the following.

* Send metadata (host, tags, attributes) about the *guest*.
* Proxy level 4 (TCP, UDP) connection to the *host* agent.
* Receive configuration from the *host* agent of what needs proxying and
  reconfigure itself accordingly.

On the *host* the tunnel is an *input* plugin called *tunnel* which accepts
connections from its *guests*.

## Protocol

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

**config** Is a JSON Object that describes which *protocol and port*
combinations the tunneling client should bind to and tunnel traffic from.
The read keys are *input* which should be an array of input configurations.

```{"bind": [{"protocol": 2, "port": 5555}, ...]}```.

After this stage, the protocol switches from text to binary mode.

Every message is a frame with the following fields.

```
HEADER:
 field | length | type | port | family | protocol | peer_addr | packet |
  size | 2      | 2    | 2    | 1      | 1        | *         | *      |

type:
  0x0000 = STATE
  0x0001 = DATA

peer_addr (family=AF_INET):
 field | ip | port |
  size | 4  | 2    |

peer_addr (family=AF_INET6):
 field | ip | port |
  size | 16 | 2    |

DATA:
 field | data |
  size | *    |

STATE:
 field | state |
  size | 2     |

state:
  ; Indicates that a remote end opened a connection to the tunnel.
  0x0000 = OPEN (SOCK_STREAM)
  ; Indicates that a remote end closed a connection to the tunnel.
  0x0001 = CLOSE (SOCK_STREAM)
```

Every numeric field greater then 2 bytes are in network byte order.

**protocol** SOCK_STREAM for *TCP* or SOCK_DGRAM for *UDP*.

**bindport** bind port number for *host* agent encoded in octets.

**family** AF_INET for *IPv4*, AF_INET6 for *IPv6*.

**ip** peer IPv4 or IPv6 address encoded in octets.

**port** peer port encoded in octets.

**data** the transferred blob of data, prefixed with 2 octets describing the
length of the payload. Maximum size of the payload is 2^16 bytes.

## Comparison to other tunneling solutions

Since most other protocols are *general purpose*, they are usually unable to do
the following.

* Collect and ffwd *metadata* to the *host* system.
* Having the *guest* proxy being dynamically reconfigured by the *host*.

**SOCKS5**

Has limited remote BIND support, specifically designed for protocols like FTP.
Connection is in the wrong direction. I.e. *host-to-guest* which would
complicate both *host* and *guest* agents due to having to manager
configuration changes on a side-channel.
*Does support* dynamic proxying.

**manual port ffwding**

One of the better alternatives.

* Does not support dynamic proxying.
  Supporting more than one *guest* at a time would require port mapping, which
  is a matter of configuration and change management on the basis of every
  individual *guest-to-host* combination.
* FFWD would have to be configured to apply metadata to incoming connections
  *depending on their ip, port* which is possible but complex.

**running the FFWD agent in every guest (no tunneling)**

The best alternative!

Keeping FFWD normalized, up to date and availble on every guest system might
be difficult. Immutable container images like with
[docker](http://www.docker.io/) make things more complicated.

It can be argued that you'd still have to run the *tunneling agent* in side the
*guest*.
This agent is a much less complex project than FFWD and therefore be subject
to less change.
