package com.spotify.ffwd.debug;

import java.util.Collection;

import lombok.extern.slf4j.Slf4j;

import com.google.inject.Inject;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;
import com.spotify.ffwd.output.PluginSink;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;

@Slf4j
public class DebugPluginSink implements PluginSink {
    @Inject
    private AsyncFramework async;

    @Override
    public AsyncFuture<Void> sendEvents(Collection<Event> events) {
        log.info("Output batch of {} event(s)", events.size());

        int i = 0;

        for (final Event e : events)
            log.info("#{}: {}", i++, e);

        return async.resolved(null);
    }

    @Override
    public AsyncFuture<Void> sendMetrics(Collection<Metric> metrics) {
        log.info("Output batch of {} metric(s)", metrics.size());

        int i = 0;

        for (final Metric m : metrics)
            log.info("#{}: {}", i++, m);

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