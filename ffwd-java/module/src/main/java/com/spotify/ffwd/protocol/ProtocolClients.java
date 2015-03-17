package com.spotify.ffwd.protocol;

import org.slf4j.Logger;

import eu.toolchain.async.AsyncFuture;

public interface ProtocolClients {
    public AsyncFuture<ProtocolConnection> connect(Logger log, Protocol protocol, ProtocolClient client);
}
