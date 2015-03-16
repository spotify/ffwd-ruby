package com.spotify.ffwd.kafka;

import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.concurrent.Callable;

import kafka.javaapi.producer.Producer;
import kafka.producer.KeyedMessage;

import com.google.inject.Inject;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;
import com.spotify.ffwd.output.BatchedPluginSink;
import com.spotify.ffwd.serializer.Serializer;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;

public class KafkaPluginSink implements BatchedPluginSink {
    @Inject
    private AsyncFramework async;

    @Inject
    private Producer<String, ByteBuffer> producer;

    @Inject
    private KafkaRouter router;

    @Inject
    private Serializer serializer;

    @Override
    public AsyncFuture<Void> sendEvent(final Event event) {
        return async.call(new Callable<Void>() {
            @Override
            public Void call() throws Exception {
                producer.send(messageFor(event));
                return null;
            }
        });
    }

    @Override
    public AsyncFuture<Void> sendMetric(final Metric metric) {
        return async.call(new Callable<Void>() {
            @Override
            public Void call() throws Exception {
                producer.send(messageFor(metric));
                return null;
            }
        });
    }

    @Override
    public AsyncFuture<Void> sendEvents(final Collection<Event> events) {
        return async.call(new Callable<Void>() {
            @Override
            public Void call() throws Exception {
                producer.send(messagesForEvents(events));
                return null;
            }
        });
    }

    @Override
    public AsyncFuture<Void> sendMetrics(final Collection<Metric> metrics) {
        return async.call(new Callable<Void>() {
            @Override
            public Void call() throws Exception {
                producer.send(messagesForMetrics(metrics));
                return null;
            }
        });
    }

    @Override
    public AsyncFuture<Void> start() {
        return async.resolved(null);
    }

    @Override
    public AsyncFuture<Void> stop() {
        return async.call(new Callable<Void>() {
            @Override
            public Void call() throws Exception {
                producer.close();
                return null;
            }
        });
    }

    private <T> List<KeyedMessage<String, ByteBuffer>> messagesForMetrics(final Collection<Metric> metrics) {
        final List<KeyedMessage<String, ByteBuffer>> messages = new ArrayList<>(metrics.size());

        for (final Metric metric : metrics)
            messages.add(messageFor(metric));

        return messages;
    }

    private <T> List<KeyedMessage<String, ByteBuffer>> messagesForEvents(final Collection<Event> events) {
        final List<KeyedMessage<String, ByteBuffer>> messages = new ArrayList<>(events.size());

        for (final Event event : events)
            messages.add(messageFor(event));

        return messages;
    }

    private KeyedMessage<String, ByteBuffer> messageFor(final Metric event) {
        final String topic = router.route(event);
        final ByteBuffer payload = serializer.serialize(event);
        return new KeyedMessage<String, ByteBuffer>(topic, payload);
    }

    private KeyedMessage<String, ByteBuffer> messageFor(final Event event) {
        final String topic = router.route(event);
        final ByteBuffer payload = serializer.serialize(event);
        return new KeyedMessage<String, ByteBuffer>(topic, payload);
    }
}