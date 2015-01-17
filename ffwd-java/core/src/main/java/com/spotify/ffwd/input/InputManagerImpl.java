package com.spotify.ffwd.input;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

import com.google.common.collect.Lists;
import com.google.inject.Inject;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;
import com.spotify.ffwd.output.OutputManager;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;
import eu.toolchain.async.Collector;

public class InputManagerImpl implements InputManager {
    @Inject
    private List<PluginSource> sources;

    @Inject
    private AsyncFramework async;

    @Inject
    private OutputManager output;

    @Override
    public void receiveEvent(Event event) {
        output.sendEvent(event);
    }

    @Override
    public void receiveMetric(Metric metric) {
        output.sendMetric(metric);
    }

    @Override
    public AsyncFuture<Void> start() {
        final ArrayList<AsyncFuture<Void>> futures = Lists.newArrayList();

        for (final PluginSource s : sources)
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

        for (final PluginSource s : sources)
            futures.add(s.stop());

        return async.collect(futures, new Collector<Void, Void>() {
            @Override
            public Void collect(Collection<Void> results) throws Exception {
                return null;
            }
        });
    }
}
