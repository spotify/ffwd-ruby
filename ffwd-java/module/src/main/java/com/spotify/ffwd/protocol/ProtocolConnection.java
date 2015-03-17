package com.spotify.ffwd.protocol;

import java.util.Collection;

import eu.toolchain.async.AsyncFuture;

public interface ProtocolConnection {
    public AsyncFuture<Void> send(Object message);

    public AsyncFuture<Void> stop();

    public AsyncFuture<Void> sendAll(Collection<? extends Object> batch);
}
