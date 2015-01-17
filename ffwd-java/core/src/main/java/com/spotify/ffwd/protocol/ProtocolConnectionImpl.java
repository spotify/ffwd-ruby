package com.spotify.ffwd.protocol;

import io.netty.channel.Channel;
import lombok.RequiredArgsConstructor;
import eu.toolchain.async.AsyncFuture;

@RequiredArgsConstructor
public class ProtocolConnectionImpl implements ProtocolConnection {
    private final Channel channel;

    @Override
    public AsyncFuture<Void> stop() {
        return null;
    }
}