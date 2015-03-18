package com.spotify.ffwd.protocol;

import io.netty.bootstrap.Bootstrap;
import io.netty.bootstrap.ServerBootstrap;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelOption;
import io.netty.channel.EventLoopGroup;
import io.netty.channel.socket.nio.NioDatagramChannel;
import io.netty.channel.socket.nio.NioServerSocketChannel;
import io.netty.util.Timer;

import org.slf4j.Logger;

import com.google.inject.Inject;
import com.google.inject.name.Named;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;

public class ProtocolServersImpl implements ProtocolServers {
    @Inject
    private AsyncFramework async;

    @Inject
    @Named("boss")
    private EventLoopGroup boss;

    @Inject
    @Named("worker")
    private EventLoopGroup worker;

    @Inject
    private Timer timer;

    @Override
    public AsyncFuture<ProtocolConnection> bind(Logger log, Protocol protocol, ProtocolServer server, RetryPolicy policy) {
        if (protocol.getType() == ProtocolType.UDP)
            return bindUDP(log, protocol, server, policy);

        if (protocol.getType() == ProtocolType.TCP)
            return bindTCP(log, protocol, server, policy);

        throw new IllegalArgumentException("Unsupported protocol: " + protocol);
    }

    private AsyncFuture<ProtocolConnection> bindTCP(final Logger log, final Protocol protocol, ProtocolServer server,
            RetryPolicy policy) {
        final ServerBootstrap b = new ServerBootstrap();

        b.group(boss, worker);
        b.channel(NioServerSocketChannel.class);
        b.childHandler(server.initializer());

        b.option(ChannelOption.SO_BACKLOG, 128);
        b.childOption(ChannelOption.SO_KEEPALIVE, true);

        final String host = protocol.getAddress().getHostString();
        final int port = protocol.getAddress().getPort();

        final RetryingProtocolConnection connection = new RetryingProtocolConnection(async, timer, log, policy,
                new ProtocolChannelSetup() {
                    @Override
                    public ChannelFuture setup() {
                        return b.bind(host, port);
                    }

                    @Override
                    public String toString() {
                        return String.format("binding to tcp://%s:%d", host, port);
                    }
                });

        return connection.getInitialFuture();
    }

    private AsyncFuture<ProtocolConnection> bindUDP(final Logger log, final Protocol protocol, ProtocolServer server,
            RetryPolicy policy) {
        final Bootstrap b = new Bootstrap();

        b.group(worker);
        b.channel(NioDatagramChannel.class);
        b.handler(server.initializer());

        final String host = protocol.getAddress().getHostString();
        final int port = protocol.getAddress().getPort();

        final RetryingProtocolConnection connection = new RetryingProtocolConnection(async, timer, log, policy,
                new ProtocolChannelSetup() {
                    @Override
                    public ChannelFuture setup() {
                        return b.bind(host, port);
                    }

                    @Override
                    public String toString() {
                        return String.format("binding to tcp://%s:%d", host, port);
                    }
                });

        return connection.getInitialFuture();
    }
}