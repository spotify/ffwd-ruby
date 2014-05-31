# Protobuf Protocol

FFWD has with a protobuf-based protocol that supports most of the features
available in the system.

This protocol is provided by the [**ffwd-protobuf**](/plugins/ffwd-protobuf)
plugin.

## Message Framing

The protocol frames messages as UDP datagrams.

Each message is a frame prefixed with the *version* and the *length* of the
entire frame.

```text
| version | length | data |
| 4       | 4      | *    |
```

The *version* field designates which version of the protocol is in use.
This determines the structure of the *data* field.

The *length* field designates how long the entire frame is supposed to be,
since UDP can crop the message this is used for detecting buffer underruns.

## Message Structure

Messages encaupsulated in the *data* field are serialized according to the
[protobuf](http://code.google.com/p/protobuf/) standard.

The following lists the currently available versions and their protobuf
definitions.

* [Version 0](/plugins/ffwd-protobuf/proto/protocol0.proto)

## Client Implementations

* [java](https://github.com/udoprog/ffwd-java-client)
* [c++](https://github.com/udoprog/libffwd-client)
