package com.spotify.ffwd.protocol;

import io.netty.channel.Channel;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelFutureListener;

import java.util.Collection;

import lombok.RequiredArgsConstructor;
import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;
import eu.toolchain.async.ResolvableFuture;

@RequiredArgsConstructor
public class ProtocolConnectionImpl implements ProtocolConnection {
    private final AsyncFramework async;
    private final Channel channel;

    @Override
    public AsyncFuture<Void> stop() {
        final ResolvableFuture<Void> future = async.future();

        channel.close().addListener(new ChannelFutureListener() {
            @Override
            public void operationComplete(ChannelFuture c) throws Exception {
                if (c.isSuccess()) {
                    future.resolve(null);
                    return;
                }

                future.fail(c.cause());
            }
        });

        return future;
    }

    @Override
    public AsyncFuture<Void> send(Object message) {
        final ResolvableFuture<Void> future = async.future();

        channel.writeAndFlush(message).addListener(new ChannelFutureListener() {
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