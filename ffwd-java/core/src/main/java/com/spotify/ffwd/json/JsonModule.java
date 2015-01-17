package com.spotify.ffwd.json;

import com.google.inject.Inject;
import com.spotify.ffwd.module.FastForwardModule;
import com.spotify.ffwd.module.PluginContext;

public class JsonModule implements FastForwardModule {
    @Inject
    private PluginContext context;

    @Override
    public void setup() throws Exception {
        context.registerInput("json", JsonInputPlugin.class);
    }
}
