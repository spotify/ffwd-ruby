package com.spotify.ffwd.input;

import eu.toolchain.async.AsyncFuture;

public interface PluginSource {
    public AsyncFuture<Void> start();

    public AsyncFuture<Void> stop();
}