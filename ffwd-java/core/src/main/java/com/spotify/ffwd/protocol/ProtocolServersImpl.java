package com.spotify.ffwd.protocol;

import io.netty.bootstrap.Bootstrap;
import io.netty.bootstrap.ServerBootstrap;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelOption;
import io.netty.channel.EventLoopGroup;
import io.netty.channel.socket.nio.NioDatagramChannel;
import io.netty.channel.socket.nio.NioServerSocketChannel;

import java.util.concurrent.TimeUnit;

import org.slf4j.Logger;

import com.google.inject.Inject;
import com.google.inject.name.Named;
import com.spotify.ffwd.protocol.ChannelUtils.ChannelAction;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;
import eu.toolchain.async.Transform;

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
    private ChannelUtils channelUtils;

    @Override
    public AsyncFuture<ProtocolConnection> bind(Logger log, Protocol protocol, ProtocolServer server) {
        if (protocol.getType() == ProtocolType.UDP)
            return bindUDP(log, protocol, server);

        if (protocol.getType() == ProtocolType.TCP)
            return bindTCP(log, protocol, server);

        throw new IllegalArgumentException("Unsupported protocol: " + protocol);
    }

    private AsyncFuture<ProtocolConnection> bindTCP(final Logger log, final Protocol protocol, ProtocolServer server) {
        final ServerBootstrap b = new ServerBootstrap();

        b.group(boss, worker);
        b.channel(NioServerSocketChannel.class);
        b.childHandler(server.initializer());

        b.option(ChannelOption.SO_BACKLOG, 128);
        b.childOption(ChannelOption.SO_KEEPALIVE, true);

        final String host = protocol.getAddress().getHostString();
        final int port = protocol.getAddress().getPort();

        return channelUtils.retry(new ChannelAction() {
            @Override
            public ChannelFuture run() {
                return b.bind(protocol.getAddress());
            }

            @Override
            public void retry(int attempt, long delay, Throwable cause) {
                final long seconds = TimeUnit.SECONDS.convert(delay, TimeUnit.MILLISECONDS);
                log.info("Bind tcp://{}:{} (attempt #{}) failed, retrying in {}s. Caused by: {}", host, port, attempt,
                        seconds, cause);
            }

            @Override
            public void success() {
                log.info("Bound to tcp://{}:{}", host, port);
            }
        }).transform(new Transform<ChannelFuture, ProtocolConnection>() {
            @Override
            public ProtocolConnection transform(ChannelFuture result) throws Exception {
                return new ProtocolConnectionImpl(async, result.channel());
            }
        });
    }

    private AsyncFuture<ProtocolConnection> bindUDP(final Logger log, final Protocol protocol, ProtocolServer server) {
        final Bootstrap b = new Bootstrap();

        b.group(worker);
        b.channel(NioDatagramChannel.class);
        b.handler(server.initializer());

        final String host = protocol.getAddress().getHostString();
        final int port = protocol.getAddress().getPort();

        return channelUtils.retry(new ChannelAction() {
            @Override
            public ChannelFuture run() {
                return b.bind(protocol.getAddress());
            }

            @Override
            public void retry(int attempt, long delay, Throwable cause) {
                final long seconds = TimeUnit.SECONDS.convert(delay, TimeUnit.MILLISECONDS);
                log.info("Bind udp://{}:{} (attempt #{}) failed, retrying in {}s. Caused by: {}", host, port, attempt,
                        seconds, cause);
            }

            @Override
            public void success() {
                log.info("Bound to udp://{}:{}", host, port);
            }
        }).transform(new Transform<ChannelFuture, ProtocolConnection>() {
            @Override
            public ProtocolConnection transform(ChannelFuture result) throws Exception {
                return new ProtocolConnectionImpl(async, result.channel());
            }
        });
    }
}