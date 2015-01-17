package com.spotify.ffwd.input;

import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;

import eu.toolchain.async.AsyncFuture;

public interface InputManager {
    /**
     * Receive a single event.
     */
    public void receiveEvent(Event event);

    /**
     * Receive a single metric.
     */
    public void receiveMetric(Metric metric);

    public AsyncFuture<Void> start();

    public AsyncFuture<Void> stop();
}
