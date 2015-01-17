# FastForward Java

This is a Java implementation of FastForward.

# Components

# Module

A module is a loadable component that extends the functionality of FastForward.
When a module is loaded it typically registers a set of plugins.

# Plugin

Either an input, or an output plugin.

This provides the implementation to read, or send data from the agent.
A plugin can have multiple _instances_ with different configurations (like
which port to listen to).

### Early Injector

The early injector is setup by AgentCore and is intended to provide the basic
facilities to perform module setup.

The following is a list of components that are given access to and their
purpose.

* _com.spotify.ffwd.module.PluginContext_ - Register input and output plugins.

### Primary Injector

The primary injector contains the dependencies which are available after
modules have been registered and the initial bootstrap is done.

It contains all the components of the early injector, with the following
additions.

* _eu.toolchain.async.AsyncFramework_ - Framework implementation to use for
  async operations.
