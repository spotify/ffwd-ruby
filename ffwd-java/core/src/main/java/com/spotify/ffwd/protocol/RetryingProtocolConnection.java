package com.spotify.ffwd.protocol;

import io.netty.channel.Channel;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelFutureListener;
import io.netty.util.Timeout;
import io.netty.util.Timer;
import io.netty.util.TimerTask;

import java.util.Collection;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

import org.slf4j.Logger;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;
import eu.toolchain.async.ResolvableFuture;

public class RetryingProtocolConnection implements ProtocolConnection {
    private final AtomicBoolean stopped = new AtomicBoolean(false);
    private final AtomicReference<Channel> channel = new AtomicReference<>();
    private final Object $lock = new Object();

    private final AsyncFramework async;
    private final Timer timer;
    private final Logger log;
    private final RetryPolicy policy;
    private final ProtocolChannelSetup action;

    private final ResolvableFuture<ProtocolConnection> initialFuture;

    public RetryingProtocolConnection(AsyncFramework async, Timer timer, Logger log, RetryPolicy policy,
            ProtocolChannelSetup action) {
        this.async = async;
        this.timer = timer;
        this.log = log;
        this.policy = policy;
        this.action = action;

        this.initialFuture = async.<ProtocolConnection> future();

        trySetup(0);
    }

    private void trySetup(final int attempt) {
        log.info("Attempt {}", action);

        final ChannelFuture connect = action.setup();

        connect.addListener(new ChannelFutureListener() {
            @Override
            public void operationComplete(ChannelFuture future) throws Exception {
                if (future.isSuccess()) {
                    log.info("Successful {}", action);
                    setChannel(future.channel());
                    return;
                }

                final long delay = policy.delay(attempt);

                log.warn("Failed {} (attempt: {}), retrying in {}s: {}", action, attempt + 1,
                        TimeUnit.SECONDS.convert(delay, TimeUnit.MILLISECONDS), future.cause().getMessage());

                timer.newTimeout(new TimerTask() {
                    @Override
                    public void run(Timeout timeout) throws Exception {
                        if (stopped.get())
                            return;

                        trySetup(attempt + 1);
                    }
                }, delay, TimeUnit.MILLISECONDS);
            }
        });
    }

    /**
     * Successfully connected, set channel to indicate that we are connected.
     */
    private void setChannel(Channel c) {
        synchronized ($lock) {
            if (stopped.get()) {
                c.close();
                return;
            }

            if (!initialFuture.isDone())
                initialFuture.resolve(this);

            channel.set(c);
        }

        c.closeFuture().addListener(new ChannelFutureListener() {
            @Override
            public void operationComplete(ChannelFuture future) throws Exception {
                log.info("Lost {}, retrying", action);
                channel.set(null);
                trySetup(0);
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
                try {
                    future.resolve(f.get());
                } catch (ExecutionException e) {
                    future.fail(e);
                }
            }
        });

        return future;
    }

    @Override
    public AsyncFuture<Void> send(Object message) {
        final Channel c = channel.get();

        if (c == null)
            return async.failed(new IllegalStateException("not connected"));

        final ResolvableFuture<Void> future = async.future();

        c.writeAndFlush(message).addListener(new ChannelFutureListener() {
            @Override
            public void operationComplete(ChannelFuture f) throws Exception {
                try {
                    future.resolve(f.get());
                } catch (ExecutionException e) {
                    future.fail(e);
                }
            }
        });

        return future;
    }

    @Override
    public AsyncFuture<Void> sendAll(Collection<? extends Object> batch) {
        return send(batch);
    }

    @Override
    public boolean isConnected() {
        final Channel c = channel.get();

        if (c == null)
            return false;

        return c.isActive();
    }

    /**
     * Return a future that will be resolved when an initial action has been successful.
     */
    public AsyncFuture<ProtocolConnection> getInitialFuture() {
        return initialFuture;
    }
}