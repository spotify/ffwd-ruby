package com.spotify.ffwd.output;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import com.google.inject.Inject;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;
import eu.toolchain.async.FutureDone;
import eu.toolchain.async.LazyTransform;
import eu.toolchain.async.ResolvableFuture;
import eu.toolchain.async.Transform;

/**
 * Facade implementation of a plugin sink that receives metrics and events, puts them on a buffer, then flushes them at
 * regular intervals.
 *
 * @author udoprog
 */
@Slf4j
@RequiredArgsConstructor
public class FlushingPluginSink implements PluginSink {
    @Inject
    private AsyncFramework async;

    @Inject
    private BatchedPluginSink sink;

    private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(5);
    private final Object $lock = new Object();
    private final AtomicReference<Batch> next = new AtomicReference<>();

    private final long flushInterval;

    @Override
    public AsyncFuture<Void> sendMetric(final Metric metric) {
        synchronized ($lock) {
            final Batch batch = next.get();

            if (batch == null)
                throw new IllegalStateException("no batch available");

            batch.metrics.add(metric);
            return batch.future;
        }
    }

    @Override
    public AsyncFuture<Void> sendEvent(Event event) {
        synchronized ($lock) {
            final Batch batch = next.get();

            if (batch == null)
                throw new IllegalStateException("no batch available");

            batch.events.add(event);
            return batch.future;
        }
    }

    @Override
    public AsyncFuture<Void> start() {
        next.set(new Batch(async.<Void> future()));

        return sink.start().transform(new Transform<Void, Void>() {
            @Override
            public Void transform(Void result) throws Exception {
                scheduler.scheduleWithFixedDelay(new Runnable() {
                    @Override
                    public void run() {
                        try {
                            flush(new Batch(async.<Void> future()));
                        } catch (final Exception e) {
                            log.error("flush failed", e);
                        }
                    }
                }, 0, flushInterval, TimeUnit.MILLISECONDS);

                return null;
            }
        });
    }

    @Override
    public AsyncFuture<Void> stop() {
        // stop scheduler -> flush remaining items -> stop sink.
        return async.call(new Callable<Void>() {
            @Override
            public Void call() throws Exception {
                // stop scheduler.
                scheduler.shutdown();
                return null;
            }
        }).transform(new LazyTransform<Void, Void>() {
            @Override
            public AsyncFuture<Void> transform(Void result) throws Exception {
                // flush remaining items and set batch to null.
                // nulling the batch will prevent any future queueing.
                return flush(null);
            }
        }).transform(new LazyTransform<Void, Void>() {
            @Override
            public AsyncFuture<Void> transform(Void result) throws Exception {
                return sink.stop();
            }
        });
    }

    @Override
    public boolean isReady() {
        return sink.isReady();
    }

    private AsyncFuture<Void> flush(final Batch nextBatch) {
        final Batch batch;

        synchronized ($lock) {
            batch = next.getAndSet(nextBatch);
        }

        final List<AsyncFuture<Void>> futures = new ArrayList<>();

        if (!batch.events.isEmpty())
            futures.add(sink.sendEvents(batch.events));

        if (!batch.metrics.isEmpty())
            futures.add(sink.sendMetrics(batch.metrics));

        // chain into batch future.
        return async.collectAndDiscard(futures).on(new FutureDone<Void>() {
            @Override
            public void failed(Throwable cause) throws Exception {
                batch.future.fail(cause);
            }

            @Override
            public void resolved(Void result) throws Exception {
                batch.future.resolve(result);
            }

            @Override
            public void cancelled() throws Exception {
                batch.future.cancel();
            }
        });
    }

    @RequiredArgsConstructor
    private static final class Batch {
        private final List<Event> events = new ArrayList<>();
        private final List<Metric> metrics = new ArrayList<>();
        private final ResolvableFuture<Void> future;
    }
}
