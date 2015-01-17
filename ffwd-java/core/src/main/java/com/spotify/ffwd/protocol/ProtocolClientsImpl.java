package com.spotify.ffwd.protocol;

import io.netty.channel.EventLoopGroup;

import com.google.inject.Inject;
import com.google.inject.name.Named;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;

public class ProtocolClientsImpl implements ProtocolClients {
    @Inject
    private AsyncFramework async;

    @Inject
    @Named("worker")
    private EventLoopGroup worker;

    @Override
    public AsyncFuture<ProtocolConnection> connect(Protocol protocol, ProtocolClient client) {
        if (protocol.getType() == ProtocolType.UDP)
            return connectUDP(protocol, client);

        if (protocol.getType() == ProtocolType.TCP)
            return connectTCP(protocol, client);

        throw new IllegalArgumentException("Unsupported protocol: " + protocol);
    }

    private AsyncFuture<ProtocolConnection> connectTCP(Protocol protocol, ProtocolClient client) {
        return async.failed(new RuntimeException("not implemented"));
    }

    private AsyncFuture<ProtocolConnection> connectUDP(Protocol protocol, ProtocolClient client) {
        return async.failed(new RuntimeException("not implemented"));
    }
}