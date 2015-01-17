package com.spotify.ffwd.protocol;

import eu.toolchain.async.AsyncFuture;

public interface ProtocolServers {
    public AsyncFuture<ProtocolConnection> bind(Protocol protocol, ProtocolServer server);
}