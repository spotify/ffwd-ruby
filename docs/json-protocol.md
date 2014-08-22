# JSON Protocol

FFWD comes with a built-in reference JSON-based protocol that supports most of the
features available in the system.

## Message Framing

This protocol either operates in `TCP line-based` or `UDP frame-based` mode.
This choice governs the use of *frame delimiter*.

For `TCP line-based` the framing is done with a newline character `\n`.

```
Client -> Server
  *connect*
  {...} \n
  ...
  *close*
```

For `UDP frame-based` the framing is assumed to be on a per datagram basis.
There is no need for a control character, you can just assume that the entire datagram is the payload.

```
Client -> Server
  {...}
  {...}
  ...
```

## Message Structure

The following sections will describe the expected JSON structure for each type of
message that can be received.

Each message is expected to be a valid JSON object with a `type` field describing the type of the object.

The available objects are documented in the following sections.

#### Metric Object

```text
{
  // required
  "type": "metric",
  // required
  "key": <string>,
  // optional
  "value": <number>,
  // optional
  "host": <string>,
  // optional
  "tags": [<string>, ...],
  // optional
  "attributes": {<string>: <string>, ...},
  // optional
  "proc": <string>,
}
````

##### proc

To see a list of the currently available processors, go look at the
implementations available in [lib/ffwd/processor](/lib/ffwd/processor).

#### Event Object

```text
{
  // required
  "type": "event",
  // required
  "key": <string>,
  // optional
  "value": <number>,
  // optional
  "host": <string>,
  // optional
  "state": <string>,
  // optional
  "description": <string>,
  // optional
  "ttl": <number>,
  // optional
  "tags": [<string>, ...],
  // optional
  "attributes": {...},
}
```

## Python Client Example

```python
import socket
import json
import time

def setup(addr=('127.0.0.1', 19000)):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    
    def send(data):
        data = json.dumps(data)
        s.sendto(data, addr)
    
    return send, s.close

if __name__ == "__main__":
    send, close = setup()
    send({"type": "metric", "key": "foo", "value": 10})
    send({"type": "event", "key": "bar", "state": "critical", "description": "Hello World"})
    close()
```
