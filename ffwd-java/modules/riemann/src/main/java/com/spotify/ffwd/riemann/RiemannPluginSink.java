package com.spotify.ffwd.riemann;

import java.util.Collection;
import java.util.concurrent.atomic.AtomicReference;

import lombok.extern.slf4j.Slf4j;

import com.google.inject.Inject;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;
import com.spotify.ffwd.output.BatchedPluginSink;
import com.spotify.ffwd.protocol.Protocol;
import com.spotify.ffwd.protocol.ProtocolClient;
import com.spotify.ffwd.protocol.ProtocolClients;
import com.spotify.ffwd.protocol.ProtocolConnection;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;
import eu.toolchain.async.LazyTransform;

@Slf4j
public class RiemannPluginSink implements BatchedPluginSink {
    @Inject
    private AsyncFramework async;

    @Inject
    private ProtocolClients clients;

    @Inject
    private Protocol protocol;

    @Inject
    private ProtocolClient client;

    private final AtomicReference<ProtocolConnection> connection = new AtomicReference<>();

    @Override
    public AsyncFuture<Void> sendEvent(Event event) {
        final ProtocolConnection c = connection.get();

        if (c == null)
            throw new IllegalStateException("not connected");

        return c.send(event);
    }

    @Override
    public AsyncFuture<Void> sendMetric(Metric metric) {
        final ProtocolConnection c = connection.get();

        if (c == null)
            throw new IllegalStateException("not connected");

        return c.send(metric);
    }

    @Override
    public AsyncFuture<Void> sendEvents(Collection<Event> events) {
        final ProtocolConnection c = connection.get();

        if (c == null)
            throw new IllegalStateException("not connected");

        return c.sendAll(events);
    }

    @Override
    public AsyncFuture<Void> sendMetrics(Collection<Metric> metrics) {
        final ProtocolConnection c = connection.get();

        if (c == null)
            throw new IllegalStateException("not connected");

        return c.sendAll(metrics);
    }

    @Override
    public AsyncFuture<Void> start() {
        return clients.connect(log, protocol, client).transform(new LazyTransform<ProtocolConnection, Void>() {
            @Override
            public AsyncFuture<Void> transform(ProtocolConnection result) throws Exception {
                if (!connection.compareAndSet(null, result))
                    return result.stop();

                return async.resolved(null);
            }
        });
    }

    @Override
    public AsyncFuture<Void> stop() {
        final ProtocolConnection c = connection.getAndSet(null);

        if (c == null)
            return async.resolved(null);

        return c.stop();
    }
}