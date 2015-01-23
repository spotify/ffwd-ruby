package com.spotify.ffwd.output;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

import com.google.common.collect.Queues;
import com.google.inject.Inject;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;

public abstract class AbstractPluginSink implements PluginSink {

    @Inject
    private AsyncFramework async;

    private final ConcurrentLinkedQueue<Event> eventsBuffer;
    private final ConcurrentLinkedQueue<Metric> metricsBuffer;
    private final ScheduledExecutorService scheduler;
    private final Integer flushInterval;

    public AbstractPluginSink() {
        this(null);
    }

    public AbstractPluginSink(final Integer flushInterval) {
        this.flushInterval = flushInterval;
        eventsBuffer = Queues.newConcurrentLinkedQueue();
        metricsBuffer = Queues.newConcurrentLinkedQueue();
        scheduler = Executors.newScheduledThreadPool(5);
    }

    @Override
    public AsyncFuture<Void> sendEvent(final Event event) {
        if (flushInterval == null) {
            doSendEvent(event);
            return async.resolved(null);
        }
        eventsBuffer.add(event);
        return async.resolved(null);
    }

    @Override
    public AsyncFuture<Void> sendMetric(final Metric metric) {
        if (flushInterval == null) {
            doSendMetric(metric);
            return async.resolved(null);
        }
        metricsBuffer.add(metric);
        return async.resolved(null);
    }

    @Override
    public AsyncFuture<Void> start() {
        if (flushInterval != null) {
            startScheduler();
        }
        return async.resolved(null);
    }

    @Override
    public AsyncFuture<Void> stop() {
        scheduler.shutdown();
        return async.resolved(null);
    }

    private void startScheduler() {
        scheduler.scheduleWithFixedDelay(new Runnable() {

            @Override
            public void run() {
                try {
                    flushBuffers();
                } catch (final Exception e) {
                    e.printStackTrace();
                }
            }
        }, 0, flushInterval, TimeUnit.SECONDS);
    }

    private void flushBuffers() {
        final List<Event> currentEvents = getCurrentElements(eventsBuffer);
        final List<Metric> currentMetrics = getCurrentElements(metricsBuffer);

        doSendAllEvents(currentEvents);
        doSendAllMetrics(currentMetrics);
    }

    private <T> List<T> getCurrentElements(final ConcurrentLinkedQueue<T> buffer) {
        final List<T> currentElements = new ArrayList<T>();
        final int size = buffer.size();
        for (int i = 0; i < size; i++) {
            currentElements.add(buffer.poll());
        }
        return currentElements;
    }

    public abstract void doSendEvent(final Event event);
    public abstract void doSendMetric(final Metric metric);
    public abstract void doSendAllEvents(final List<Event> events);
    public abstract void doSendAllMetrics(final List<Metric> metrics);
}
