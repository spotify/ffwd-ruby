package com.spotify.ffwd.kafka;

import lombok.ToString;

import com.google.inject.Inject;
import com.spotify.ffwd.module.FastForwardModule;
import com.spotify.ffwd.module.PluginContext;

@ToString(of={})
public class KafkaModule implements FastForwardModule {
    @Inject
    private PluginContext context;

    @Override
    public void setup() {
        context.registerOutput("kafka", KafkaOutputPlugin.class);
    }
}