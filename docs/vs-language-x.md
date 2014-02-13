# Why is FFWD written in Ruby?

## Interpreted language

Since most of the inspiration for FFWD comes from
[collectd](https://collectd.org) the big contrast is that ruby is an
interpreted language.

We acknowledge the fact that there will always be buggy code, and believe that
languages like ruby and python gives you the ability to debug the application
on a high level (gdb, ruby -rdebug). And if necessary modify the code  in the
environment which causes the bug to be triggered.

While it is possible to write code that facilititates troubleshooting, the cost
of getting it right up front is higher in compiled languages (C, java) than for
intepreted ones.

## But what about python?

The main difference between ruby and python for this projects lies in the use
of blocks in combination with an [event-driven framework](#EventMachine).

## EventMachine

An early design decision was to make FFWD event-driven.

[EventMachine](http://rubyeventmachine.com/) is an incredible project, similar
to [twisted](https://twistedmatrix.com/trac/) (python) and
[netty](http://netty.io/) (java) in the problem domain.

We believe that the way that you express implementations in EventMachine
compared to other event-driven frameworks is very terse, leading to a smaller
implementation and lower development cost.

EventMachine itself also has a rich set of libraries and components which makes
a lot of common tasks you would expect from a component like FFWD easier.

Some examples are.

* [Fully asynchronous http requests.](https://github.com/igrigorik/em-http-request).
* [Deferring blocking work to a thread pool.](http://eventmachine.rubyforge.org/EventMachine.html#defer-class_method)>
* [Numerous complete and partial protocol implementations.](https://github.com/eventmachine/eventmachine/wiki/Protocol-Implementations)
* Simple to integrate timers ([Timer](http://eventmachine.rubyforge.org/EventMachine/Timer.html), [PeriodicTimer](http://eventmachine.rubyforge.org/EventMachine/PeriodicTimer.html)).
