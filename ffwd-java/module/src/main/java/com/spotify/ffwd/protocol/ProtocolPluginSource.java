package com.spotify.ffwd.protocol;

import java.util.concurrent.atomic.AtomicReference;

import org.slf4j.Logger;

import com.google.inject.Inject;
import com.spotify.ffwd.input.PluginSource;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;
import eu.toolchain.async.Transform;

public class ProtocolPluginSource implements PluginSource {
    @Inject
    private AsyncFramework async;

    @Inject
    private ProtocolServers servers;

    @Inject
    private Protocol protocol;

    @Inject
    private ProtocolServer server;

    @Inject
    private RetryPolicy retry;

    @Inject
    private Logger log;

    private final AtomicReference<ProtocolConnection> connection = new AtomicReference<>();

    @Override
    public AsyncFuture<Void> start() {
        return servers.bind(log, protocol, server, retry).transform(new Transform<ProtocolConnection, Void>() {
            @Override
            public Void transform(ProtocolConnection c) throws Exception {
                if (!connection.compareAndSet(null, c))
                    c.stop();

                return null;
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