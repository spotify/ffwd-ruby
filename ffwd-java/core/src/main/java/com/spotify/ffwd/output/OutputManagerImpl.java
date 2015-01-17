package com.spotify.ffwd.output;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.Set;

import com.google.common.collect.Lists;
import com.google.common.collect.Maps;
import com.google.common.collect.Sets;
import com.google.inject.Inject;
import com.google.inject.name.Named;
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

    @Inject
    @Named("attributes")
    private Map<String, String> attributes;

    @Inject
    @Named("tags")
    private Set<String> tags;

    @Inject
    @Named("ttl")
    private long ttl;

    @Override
    public void sendEvent(Event event) {
        final Event filtered = filter(event);

        for (final PluginSink s : sinks)
            s.sendEvent(filtered);
    }

    @Override
    public void sendMetric(Metric metric) {
        final Metric filtered = filter(metric);

        for (final PluginSink s : sinks)
            s.sendMetric(filtered);
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

    /**
     * Filter the provided Event and complete fields.
     */
    private Event filter(Event event) {
        if (attributes.isEmpty() && tags.isEmpty() && ttl == 0)
            return event;

        final Map<String, String> a = Maps.newHashMap(attributes);
        a.putAll(event.getAttributes());

        final Set<String> t = Sets.newHashSet(tags);
        t.addAll(event.getTags());

        final Date time = event.getTime() != null ? event.getTime() : new Date();
        final Long ttl = event.getTtl() != 0 ? event.getTtl() : this.ttl;

        return new Event(event.getKey(), event.getValue(), time, ttl, event.getState(), event.getDescription(),
                event.getHost(), t, a);
    }

    /**
     * Filter the provided Metric and complete fields.
     */
    private Metric filter(Metric metric) {
        if (attributes.isEmpty() && tags.isEmpty())
            return metric;

        final Map<String, String> a = Maps.newHashMap(attributes);
        a.putAll(metric.getAttributes());

        final Set<String> t = Sets.newHashSet(tags);
        t.addAll(metric.getTags());

        final Date time = metric.getTime() != null ? metric.getTime() : new Date();

        return new Metric(metric.getKey(), metric.getValue(), time, metric.getHost(), t, a, metric.getProc());
    }
}