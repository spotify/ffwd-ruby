package com.spotify.ffwd.protocol;

import io.netty.bootstrap.Bootstrap;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelOption;
import io.netty.channel.EventLoopGroup;
import io.netty.channel.socket.nio.NioSocketChannel;
import io.netty.util.Timer;

import org.slf4j.Logger;

import com.google.inject.Inject;
import com.google.inject.name.Named;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;

public class ProtocolClientsImpl implements ProtocolClients {
    private final long TIMEOUT_BASE = 1;

    @Inject
    private AsyncFramework async;

    @Inject
    @Named("worker")
    private EventLoopGroup worker;

    @Inject
    private Timer timer;

    @Override
    public AsyncFuture<ProtocolConnection> connect(Logger log, Protocol protocol, ProtocolClient client,
            RetryPolicy policy) {
        if (protocol.getType() == ProtocolType.UDP)
            return connectUDP(protocol, client, policy);

        if (protocol.getType() == ProtocolType.TCP)
            return connectTCP(log, protocol, client, policy);

        throw new IllegalArgumentException("Unsupported protocol: " + protocol);
    }

    private AsyncFuture<ProtocolConnection> connectTCP(Logger log, Protocol protocol, ProtocolClient client,
            RetryPolicy policy) {
        final Bootstrap b = new Bootstrap();

        b.group(worker);
        b.channel(NioSocketChannel.class);
        b.handler(client.initializer());

        b.option(ChannelOption.SO_KEEPALIVE, true);

        final String host = protocol.getAddress().getHostString();
        final int port = protocol.getAddress().getPort();

        final ProtocolConnection connection = new RetryingProtocolConnection(async, timer, log, policy,
                new ProtocolChannelSetup() {
                    @Override
                    public ChannelFuture setup() {
                        return b.connect(host, port);
                    }

                    @Override
                    public String toString() {
                        return String.format("connecting to tcp://%s:%d", host, port);
                    }
                });

        return async.resolved(connection);
    }

    private AsyncFuture<ProtocolConnection> connectUDP(Protocol protocol, ProtocolClient client, RetryPolicy policy) {
        return async.failed(new RuntimeException("not implemented"));
    }
}