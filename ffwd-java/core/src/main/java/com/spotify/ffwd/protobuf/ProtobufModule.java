package com.spotify.ffwd.protobuf;

import com.google.inject.Inject;
import com.spotify.ffwd.module.FastForwardModule;
import com.spotify.ffwd.module.PluginContext;

public class ProtobufModule implements FastForwardModule {
    @Inject
    private PluginContext context;

    @Override
    public void setup() throws Exception {
        context.registerInput("protobuf", ProtobufInputPlugin.class);
    }
}
