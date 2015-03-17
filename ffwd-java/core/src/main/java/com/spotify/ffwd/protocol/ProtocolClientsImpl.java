package com.spotify.ffwd.protocol;

import io.netty.bootstrap.Bootstrap;
import io.netty.channel.Channel;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelFutureListener;
import io.netty.channel.ChannelOption;
import io.netty.channel.EventLoopGroup;
import io.netty.channel.socket.nio.NioSocketChannel;
import io.netty.util.Timeout;
import io.netty.util.Timer;
import io.netty.util.TimerTask;

import java.util.Collection;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

import org.slf4j.Logger;

import com.google.inject.Inject;
import com.google.inject.name.Named;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;
import eu.toolchain.async.ResolvableFuture;

public class ProtocolClientsImpl implements ProtocolClients {
    private final long TIMEOUT_BASE = 1;

    @Inject
    private AsyncFramework async;

    @Inject
    @Named("worker")
    private EventLoopGroup worker;

    @Inject
    private Timer timer;

    @Inject
    private ChannelUtils channelUtils;

    @Override
    public AsyncFuture<ProtocolConnection> connect(Logger log, Protocol protocol, ProtocolClient client) {
        if (protocol.getType() == ProtocolType.UDP)
            return connectUDP(protocol, client);

        if (protocol.getType() == ProtocolType.TCP)
            return connectTCP(log, protocol, client);

        throw new IllegalArgumentException("Unsupported protocol: " + protocol);
    }

    private AsyncFuture<ProtocolConnection> connectTCP(Logger log, Protocol protocol, ProtocolClient client) {
        final Bootstrap b = new Bootstrap();

        b.group(worker);
        b.channel(NioSocketChannel.class);
        b.handler(client.initializer());

        b.option(ChannelOption.SO_KEEPALIVE, true);

        final String host = protocol.getAddress().getHostString();
        final int port = protocol.getAddress().getPort();

        final ProtocolConnection connection = new TCPProtocolConnection(log, b, host, port);
        return async.resolved(connection);
    }

    private AsyncFuture<ProtocolConnection> connectUDP(Protocol protocol, ProtocolClient client) {
        return async.failed(new RuntimeException("not implemented"));
    }

    private final class TCPProtocolConnection implements ProtocolConnection {
        private final Logger log;
        private final Bootstrap bootstrap;
        private final String host;
        private final int port;

        private final AtomicBoolean stopped = new AtomicBoolean(false);
        private final AtomicReference<Channel> channel = new AtomicReference<>();
        private final Object $lock = new Object();

        public TCPProtocolConnection(Logger log, Bootstrap bootstrap, String host, int port) {
            this.log = log;
            this.bootstrap = bootstrap;
            this.host = host;
            this.port = port;

            // initial connection attempt
            tryConnect(0);
        }

        private void tryConnect(final int attempt) {
            log.info("attempt to connect to tcp://{}:{}", host, port);

            final ChannelFuture connect = bootstrap.connect(host, port);

            connect.addListener(new ChannelFutureListener() {
                @Override
                public void operationComplete(ChannelFuture future) throws Exception {
                    if (future.isSuccess()) {
                        log.info("connected to tcp://{}:{}", host, port);
                        setChannel(future.channel());
                        return;
                    }

                    final long delay = TIMEOUT_BASE * (long) Math.pow(2, attempt);

                    log.warn("failed connecting to tcp://{}:{} (attempt: {}), retrying in {}s: {}", host, port,
                            attempt + 1, delay, future.cause().getMessage(), future.cause());

                    timer.newTimeout(new TimerTask() {
                        @Override
                        public void run(Timeout timeout) throws Exception {
                            if (stopped.get())
                                return;

                            tryConnect(attempt + 1);
                        }
                    }, delay, TimeUnit.SECONDS);
                }
            });
        }

        /**
         * Successfully connected, setting channel.
         */
        private void setChannel(Channel c) {
            synchronized ($lock) {
                if (stopped.get()) {
                    c.close();
                    return;
                }

                channel.set(c);
            }

            c.closeFuture().addListener(new ChannelFutureListener() {
                @Override
                public void operationComplete(ChannelFuture future) throws Exception {
                    log.info("lost connection, reconnecting...");
                    tryConnect(0);
                }
            });
        }

        @Override
        public AsyncFuture<Void> stop() {
            final Channel c;

            synchronized ($lock) {
                stopped.set(true);

                c = channel.getAndSet(null);

                if (c == null)
                    return async.resolved(null);
            }

            final ResolvableFuture<Void> future = async.future();

            c.close().addListener(new ChannelFutureListener() {
                @Override
                public void operationComplete(ChannelFuture f) throws Exception {
                    if (!f.isSuccess()) {
                        future.fail(f.cause());
                        return;
                    }

                    future.resolve(null);
                }
            });

            return future;
        }

        @Override
        public AsyncFuture<Void> send(Object message) {
            final Channel c = channel.get();

            if (c == null)
                throw new IllegalStateException("not connected");

            final ResolvableFuture<Void> future = async.future();

            c.writeAndFlush(message).addListener(new ChannelFutureListener() {
                @Override
                public void operationComplete(ChannelFuture f) throws Exception {
                    if (f.isSuccess()) {
                        future.resolve(null);
                        return;
                    }

                    future.fail(f.cause());
                }
            });

            return future;
        }

        @Override
        public AsyncFuture<Void> sendAll(Collection<? extends Object> batch) {
            return send(batch);
        }
    }
}