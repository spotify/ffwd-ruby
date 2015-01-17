package com.spotify.ffwd.protobuf;

import java.util.concurrent.atomic.AtomicReference;

import com.google.inject.Inject;
import com.spotify.ffwd.input.PluginSource;
import com.spotify.ffwd.protocol.Protocol;
import com.spotify.ffwd.protocol.ProtocolConnection;
import com.spotify.ffwd.protocol.ProtocolServers;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;
import eu.toolchain.async.Transform;

public class ProtobufPluginSource implements PluginSource {
    @Inject
    private AsyncFramework async;

    @Inject
    private ProtocolServers servers;

    @Inject
    private Protocol protocol;

    @Inject
    private ProtobufUDPProtocolServer server;

    private final AtomicReference<ProtocolConnection> connection = new AtomicReference<>();

    @Override
    public AsyncFuture<Void> start() {
        return servers.bind(protocol, server).transform(new Transform<ProtocolConnection, Void>() {
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