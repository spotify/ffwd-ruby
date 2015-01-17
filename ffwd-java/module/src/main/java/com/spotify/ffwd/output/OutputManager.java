package com.spotify.ffwd.output;

import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;

import eu.toolchain.async.AsyncFuture;

public interface OutputManager {
    /**
     * Send a collection of events to all output plugins.
     */
    public void sendEvent(Event event);

    /**
     * Send a collection of metrics to all output plugins.
     */
    public void sendMetric(Metric metric);

    public AsyncFuture<Void> start() throws Exception;

    public AsyncFuture<Void> stop();
}
