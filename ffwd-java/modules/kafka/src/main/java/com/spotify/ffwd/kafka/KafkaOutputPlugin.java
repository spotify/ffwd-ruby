package com.spotify.ffwd.kafka;

import java.util.Collection;

import com.google.inject.Inject;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;
import com.spotify.ffwd.module.OutputPlugin;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;

public class KafkaOutputPlugin implements OutputPlugin {
    @Inject
    private AsyncFramework async;

    @Override
    public AsyncFuture<Void> sendEvents(Collection<Event> event) {
        return async.resolved(null);
    }

    @Override
    public AsyncFuture<Void> sendMetrics(Collection<Metric> metrics) {
        return async.resolved(null);
    }
}