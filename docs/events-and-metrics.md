# Events and Metrics

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
[lib/ffwd/event.rb](/lib/ffwd/event.rb) and
[lib/ffwd/metric.rb](/lib/ffwd/metric.rb).

## Input Data Structure

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
statsd plugin](/lib/ffwd/plugin/statsd.rb) for a good example where only
**:key**, **:value** and **:proc** is used.

## Output Data Structure

After *data* has been emitted by a plugin, processed by *Core*, it is then
converted into a *Struct* and treated as **output** (see
[MetricEmitter](/lib/ffwd/metric_emitter.rb) and
[EventEmitter](/lib/ffwd/event_emitter.rb)).

This causes the events and metrics to be *consistent* and more type safe when
it reaches and *output plugin*.
The *output data* is then converted by the output plugin to suit whatever
the target protocol requires.

An *output plugin* can and often will omit fields which cannot be sanely
converted to the target protocol.
Instead it is up to the system administrator to choose an output scheme which
match their requirements.
