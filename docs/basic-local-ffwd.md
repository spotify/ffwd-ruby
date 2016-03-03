#Basic Local FFWD
This is the step by step instruction of how to setup a basic local FFWD from scratch for debugging purpose.
The FFWD instance we will setup only has input JSON protocol and debugging enabled.

* **Initial state:** No ffwd installed

1- Install FFWD:
```bash
$ gem install ffwd
```
2- Create the configuration file in your local directory (any directory). Let's say the file name is **myconfig.yml**:
```bash
:input:
  - :type: "json"
    :kind: :line
  - :type: "json"
    :kind: :frame

:debug: {}
```
This will activates [JSON protocol] (/docs/json-protocol.md) in FFWD. The last line activates [debugging](https://github.com/spotify/ffwd#debugging).

3- Install protobuf plugin
```bash
$ gem install ffwd-protobuf
```
4- Enable [protobuf plugin](/docs/protobuf-protocol.md) in the config by adding the following to the configuration file:
```bash
:input:
  - :type: "protobuf"
    :receive_buffer_size: 26214400
```
5- run FFWD:
```bash
$ ffwd myconfig.yml
```
6- Now in a separate terminal shell start the FFWD debugger:
```bash
$ fwc --raw
```
Now we can see every input data that FFWD receives.
