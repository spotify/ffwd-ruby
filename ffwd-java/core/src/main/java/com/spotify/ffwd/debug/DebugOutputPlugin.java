package com.spotify.ffwd.debug;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.google.inject.Key;
import com.google.inject.Module;
import com.google.inject.PrivateModule;
import com.google.inject.Scopes;
import com.spotify.ffwd.output.BatchedPluginSink;
import com.spotify.ffwd.output.FlushingPluginSink;
import com.spotify.ffwd.output.OutputPlugin;
import com.spotify.ffwd.output.PluginSink;

public class DebugOutputPlugin implements OutputPlugin {
    private final Long flushInterval;

    @JsonCreator
    public DebugOutputPlugin(@JsonProperty("flushInterval") Long flushInterval) {
        this.flushInterval = flushInterval;
    }

    @Override
    public Module module(final Key<PluginSink> key) {
        return new PrivateModule() {
            @Override
            protected void configure() {
                if (flushInterval != null) {
                    bind(BatchedPluginSink.class).to(DebugPluginSink.class);
                    bind(key).toInstance(new FlushingPluginSink(flushInterval));
                } else {
                    bind(key).to(DebugPluginSink.class).in(Scopes.SINGLETON);
                }

                expose(key);
            }
        };
    }
}