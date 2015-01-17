package com.spotify.ffwd.debug;

import com.google.inject.Inject;
import com.spotify.ffwd.module.FastForwardModule;
import com.spotify.ffwd.module.PluginContext;

public class DebugModule implements FastForwardModule {
    @Inject
    private PluginContext context;

    @Override
    public void setup() throws Exception {
        context.registerOutput("debug", DebugOutputPlugin.class);
    }
}
