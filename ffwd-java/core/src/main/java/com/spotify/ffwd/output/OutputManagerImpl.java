package com.spotify.ffwd.output;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

import com.google.common.collect.Lists;
import com.google.inject.Inject;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;
import eu.toolchain.async.Collector;

public class OutputManagerImpl implements OutputManager {
    @Inject
    private List<PluginSink> sinks;

    @Inject
    private AsyncFramework async;

    @Override
    public void sendEvents(Collection<Event> events) {
    }

    @Override
    public void sendMetrics(Collection<Metric> metrics) {
    }

    @Override
    public AsyncFuture<Void> start() throws Exception {
        final ArrayList<AsyncFuture<Void>> futures = Lists.newArrayList();

        for (final PluginSink s : sinks)
            futures.add(s.start());

        return async.collect(futures, new Collector<Void, Void>() {
            @Override
            public Void collect(Collection<Void> results) throws Exception {
                return null;
            }
        });
    }

    @Override
    public AsyncFuture<Void> stop() {
        final ArrayList<AsyncFuture<Void>> futures = Lists.newArrayList();

        for (final PluginSink s : sinks)
            futures.add(s.stop());

        return async.collect(futures, new Collector<Void, Void>() {
            @Override
            public Void collect(Collection<Void> results) throws Exception {
                return null;
            }
        });
    }
}