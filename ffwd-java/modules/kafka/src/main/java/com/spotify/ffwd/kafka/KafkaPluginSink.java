package com.spotify.ffwd.kafka;

import com.google.inject.Inject;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;
import com.spotify.ffwd.output.PluginSink;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;

public class KafkaPluginSink implements PluginSink {
    @Inject
    private AsyncFramework async;

    @Override
    public AsyncFuture<Void> sendEvent(Event event) {
        return async.resolved(null);
    }

    @Override
    public AsyncFuture<Void> sendMetric(Metric metric) {
        return async.resolved(null);
    }

    @Override
    public AsyncFuture<Void> start() {
        return async.resolved(null);
    }

    @Override
    public AsyncFuture<Void> stop() {
        return async.resolved(null);
    }
}