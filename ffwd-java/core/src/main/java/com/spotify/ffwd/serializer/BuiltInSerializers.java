package com.spotify.ffwd.serializer;

import com.google.inject.Inject;
import com.spotify.ffwd.module.FastForwardModule;
import com.spotify.ffwd.module.PluginContext;

public class BuiltInSerializers implements FastForwardModule {
    @Inject
    private PluginContext context;

    @Override
    public void setup() throws Exception {
        context.registerSerializer("spotify100", Spotify100Serializer.class);
    }
}
