# EVD vs. collectd

EVD is heavily inspired by [collectd](http://collectd.org/) but is designed
with a different core use-case and design principles.

## collectd collects. EVD only receives.

**EVD** does not have collection plugins, instead it relies on the system
administrator too choose which is the most appropriate method of collecting and
supports a wide array of community accepted protocols to receive them.

**collectd** does as well support alternative input protocols and is indeed
moving towards being more *middleware*-oriented.

However, doing collection inside the agent puts strains on the architecture
which we intend to avoid with **EVD**.

That being said, it is possible to run collectd and having it send metrics
through **EVD**.

## collectd is a native application. EVD is ruby.

This makes **EVD** slower.

It also distinguishes **EVD** in that.

* **memory management** is easier.
* **dynamic datastructures** are readily available.
* **error conditions** can be handled by fewer lines of codes, usually simply
  by correct exception handling (but not always!).
* A ton of easy to use libraries are available in ruby. While both a blessing
  and a curse it typically means fewer lines of codes compared to their
  C counterpart, which allows for faster development iterations.

## collectd relies on threads. EVD is [event-based](http://rubyeventmachine.com/).

The use of threads is not controversial, but having the *Core* of **EVD**
running on a single thread means that a lot of tasks to allow for introspection
are easier to implement. **collectd** being a bit of a black box has always
been an issue to us.

This does however mean that plugin authors have to be aware that their
*consumption* loop could potentially block the entire application.

However, since **EVD** only focuses on *forwarding* from one type of plugin to
another, we expect the amount of plugins to be far less than that of
**collectd**.

## collectd saves metrics. EVD drops metrics.

Now building a reliable transport for metrics is *hard*, in EVD we've opted for
*dropping* information, but making the system *aware* of that it's doing it.

*Core* has no buffers, instead it is up to each individual output plugin to
decide weither they should or should not buffer their data.
Most plugins that we have written use the following scheme.

1. Data received is put on a small (limited) buffer.
2. Data is periodically batched.
3. *If batching takes longer than the configured period*,
   start dropping data.
4. Generate new metrics indicating that data is being dropped, display them on
   a side-channel.

There are other schemes possible (like probabilistic dropping proportional to
the buffer size as used by collectd), but that is completely up to the output
plugin.
