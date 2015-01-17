package com.spotify.ffwd.protocol;

import eu.toolchain.async.AsyncFuture;

public interface ProtocolConnection {
    public AsyncFuture<Void> stop();
}
