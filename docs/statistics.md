# Statistics

FFWD reports internal statistics allowing for an insight into what is going on.

All statistics are reported as internally generated metrics with a rich set of
tags.

The following sections document what metrics various models generate.

### FFWD::PluginChannel

Plugin channels are a combination of *two* regular channels, one for events and
one for metrics.

<dl>
  <dt>ffwd.events {type="plugin_channel", plugin_channel=*type of plugin channel*}</dt>
  <dd>Events being processed by internal channels.</dd>
  <dt>ffwd.metrics {type="plugin_channel", plugin_channel=*type of plugin channel*}</dt>
  <dd>Metrics being processed by internal channels.</dd>
</dl>

### FFWD::UDP::Bind

Module used as a basis for plugins intended to receive events or metrics over
UDP.

All plugins implementing FFWD::UDP::Bind has the following set of tags.

*Note: A specific plugin can also provide it's own set of tags.*

<dl>
  <dt>family</dt>
  <dd>"udp"</dd>
  <dt>type</dt>
  <dd>The type of the reporter, typically the input plugin.</dd>
  <dt>listen</dt>
  <dd>The host and port combination that the current plugin listens to
  (*host*:*port*)</dd>
</dl>

The following are the metrics emitted by FFWD::UDP::Bind.

<dl>
  <dt>ffwd.received_events</dt>
  <dd>Event received.</dd>
  <dt>ffwd.received_metrics</dt>
  <dd>Metrics received.</dd>
  <dt>ffwd.failed_events</dt>
  <dd>Event that could not be received because of internal errors.</dd>
  <dt>ffwd.failed_metrics</dt>
  <dd>Metrics that could not be received because of internal errors.</dd>
</dl>

### FFWD::TCP::Bind

Module used as a basis for plugins intended to receive events or metrics over
TCP.

All plugins implementing FFWD::TCP::Bind has the following set of tags.

*Note: A specific plugin can also provide it's own set of tags.*

<dl>
  <dt>family</dt>
  <dd>"tcp"</dd>
  <dt>type</dt>
  <dd>The type of the reporter, typically the input plugin.</dd>
  <dt>listen</dt>
  <dd>The host and port combination that the current plugin listens to
  (*host*:*port*)</dd>
</dl>

The following are the metrics emitted by FFWD::TCP::Bind.

<dl>
  <dt>ffwd.received_events</dt>
  <dd>Event received.</dd>
  <dt>ffwd.received_metrics</dt>
  <dd>Metrics received.</dd>
  <dt>ffwd.failed_events</dt>
  <dd>Event that could not be received because of internal errors.</dd>
  <dt>ffwd.failed_metrics</dt>
  <dd>Metrics that could not be received because of internal errors.</dd>
</dl>

### FFWD::UDP::Connect

UDP connection to a specific peer.
Should not be confused with a stateful connection, it is only used to maintain
which peer this specific instance is communicating with.

All plugins implementing FFWD::UDP::Connect has the following set of
tags.

*Note: A specific plugin can also provide it's own set of tags.*

<dl>
  <dt>type</dt>
  <dd>the type of the metric, this is typically provided by the plugin in
  use.</dd>
  <dt>peer</dt>
  <dd>The peer you are currently sending to (*host*:*port*)</dd>
</dl>

<dl>
  <dt>ffwd.dropped_events</dt>
  <dd>Events being dropped.</dd>
  <dt>ffwd.dropped_metrics</dt>
  <dd>Metrics being dropped.</dd>
  <dt>ffwd.sent_events</dt>
  <dd>Events that have been successfully sent.</dd>
  <dt>ffwd.sent_metrics</dt>
  <dd>Metrics that have been successfully sent.</dd>
</dl>

### FFWD::TCP::PlainConnect

Plain connections are what is being used with TCP when flush_period is set to
a non-positive value.
They are intended to forward the received data as soon as possible.

<dl>
  <dt>ffwd.dropped_events</dt>
  <dd>Events being dropped.</dd>
  <dt>ffwd.dropped_metrics</dt>
  <dd>Metrics being dropped.</dd>
  <dt>ffwd.sent_events</dt>
  <dd>Events that have been successfully sent.</dd>
  <dt>ffwd.sent_metrics</dt>
  <dd>Metrics that have been successfully sent.</dd>
  <dt>ffwd.failed_events</dt>
  <dd>Events that could not be sent because of internal errors.</dd>
  <dt>ffwd.failed_metrics</dt>
  <dd>Metrics that could not be sent because of internal errors.</dd>
</dl>

### FFWD::TCP::FlushingConnect

Flushing connections are what is being used when flush_interval is set to
a positive non-zero value.
They are intended to buffer data and flush tham at timely intervals.

All plugins implementing FFWD::TCP::FlushingConnect has the following set of
tags.

*Note: A specific plugin can also provide it's own set of tags.*

<dl>
  <dt>type</dt>
  <dd>the type of the metric, this is typically provided by the plugin in
  use.</dd>
  <dt>peer</dt>
  <dd>The peer you are currently connected to (*host*:*port*)</dd>
</dl>

The following are the metrics emitted by FFWD::TCP::FlushingConnect.

<dl>
  <dt>ffwd.dropped_events</dt>
  <dd>Events being dropped for various reasons.</dd>
  <dt>ffwd.dropped_metrics</dt>
  <dd>Metrics being dropped for various reasons.</dd>
  <dt>ffwd.sent_events</dt>
  <dd>Events that have been successfully sent.</dd>
  <dt>ffwd.sent_metrics</dt>
  <dd>Metrics that have been successfully sent.</dd>
  <dt>ffwd.failed_events</dt>
  <dd>Events that could not be sent because of internal errors.</dd>
  <dt>ffwd.failed_metrics</dt>
  <dd>Metrics that could not be sent because of internal errors.</dd>
  <dt>ffwd.forced_flush</dt>
  <dd>Buffer flushes forced because flush_limit for either events or metrics
  was met.</dd>
</dl>
