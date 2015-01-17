package com.spotify.ffwd.protocol;

import eu.toolchain.async.AsyncFuture;

public interface ProtocolClients {
    public AsyncFuture<ProtocolConnection> connect(Protocol protocol, ProtocolClient client);
}
