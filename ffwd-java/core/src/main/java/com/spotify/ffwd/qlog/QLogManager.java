package com.spotify.ffwd.qlog;

import java.io.IOException;
import java.nio.ByteBuffer;

import eu.toolchain.async.AsyncFuture;

public interface QLogManager {
    public long position();

    /**
     * Trim the head of the on-disk log (if necessary).
     *
     * @param position The position to trim to.
     */
    public void trim(long position);

    public void trim();

    public long write(ByteBuffer buffer) throws IOException;

    public void update(String id, long position);

    public AsyncFuture<Void> start();

    public AsyncFuture<Void> stop();
}