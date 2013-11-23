# General

EVD is built on top of EventMachine.

Plugins must be written on top of EventMachine.

# Input Plugin

Responsible for receiving events.

Received messages are expected to be a dictionary with the following fields.

* $type - Determines the data type of the received event (how it should be processed).
* key - Key of the received event.
* *other* - Other fields specific to the data type.

# Output Plugin

Responsible for dispatching events to third party systems.

Each instance of an output plugin has an isolated write queue.
If the buffer is full, messages will not be queue until events has been
processed.

# Data Type

A data type decides how incoming events should be processed.
