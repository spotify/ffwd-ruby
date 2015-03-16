package com.spotify.ffwd.debug;

import java.util.Collection;

import lombok.extern.slf4j.Slf4j;

import com.google.inject.Inject;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;
import com.spotify.ffwd.output.BatchedPluginSink;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;

@Slf4j
public class DebugPluginSink implements BatchedPluginSink {
    @Inject
    private AsyncFramework async;

    @Override
    public AsyncFuture<Void> sendEvent(Event event) {
        log.info("E: {}", event);
        return async.resolved(null);
    }

    @Override
    public AsyncFuture<Void> sendMetric(Metric metric) {
        log.info("M: {}", metric);
        return async.resolved(null);
    }

    @Override
    public AsyncFuture<Void> sendEvents(Collection<Event> events) {
        int i = 0;

        for (final Event e : events)
            log.info("E#{}: {}", i++, e);

        return async.resolved(null);
    }

    @Override
    public AsyncFuture<Void> sendMetrics(Collection<Metric> metrics) {
        int i = 0;

        for (final Metric m : metrics)
            log.info("E#{}: {}", i++, m);

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