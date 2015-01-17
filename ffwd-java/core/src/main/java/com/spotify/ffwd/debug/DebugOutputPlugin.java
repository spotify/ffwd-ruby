package com.spotify.ffwd.debug;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.google.inject.Key;
import com.google.inject.Module;
import com.google.inject.PrivateModule;
import com.spotify.ffwd.output.OutputPlugin;
import com.spotify.ffwd.output.PluginSink;

public class DebugOutputPlugin implements OutputPlugin {
    @JsonCreator
    public DebugOutputPlugin() {
    }

    @Override
    public Module module(final Key<PluginSink> key) {
        return new PrivateModule() {
            @Override
            protected void configure() {
                bind(key).to(DebugPluginSink.class);
                expose(key);
            }
        };
    }
}