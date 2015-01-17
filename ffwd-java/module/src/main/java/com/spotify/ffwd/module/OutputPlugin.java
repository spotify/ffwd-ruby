package com.spotify.ffwd.module;

import java.util.Collection;

import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;

import eu.toolchain.async.AsyncFuture;

public interface OutputPlugin {
    /**
     * Send the given collection of events.
     *
     * @param events Collection of events to send.
     * @return A future that will be resolved when the events have been sent.
     */
    public AsyncFuture<Void> sendEvents(Collection<Event> events);

    /**
     * Send the given collection of metrics.
     *
     * @param metrics Metrics to send.
     * @return A future that will be resolved when the metrics have been sent.
     */
    public AsyncFuture<Void> sendMetrics(Collection<Metric> metrics);
}
