package com.spotify.ffwd.output;

import java.util.Collection;

import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;

import eu.toolchain.async.AsyncFuture;

public interface OutputManager {
    /**
     * Send a collection of events to all output plugins.
     */
    public void sendEvents(Collection<Event> events);

    /**
     * Send a collection of metrics to all output plugins.
     */
    public void sendMetrics(Collection<Metric> metrics);

    public AsyncFuture<Void> start() throws Exception;

    public AsyncFuture<Void> stop();
}
