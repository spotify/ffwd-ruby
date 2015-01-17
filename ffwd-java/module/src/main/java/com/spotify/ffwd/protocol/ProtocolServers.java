package com.spotify.ffwd.protocol;

import org.slf4j.Logger;

import eu.toolchain.async.AsyncFuture;

public interface ProtocolServers {
    public AsyncFuture<ProtocolConnection> bind(Logger log, Protocol protocol, ProtocolServer server);
}