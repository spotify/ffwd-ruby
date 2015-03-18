package com.spotify.ffwd.kafka;

import java.nio.charset.Charset;
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
    private static final Charset UTF8 = Charset.forName("UTF-8");

    @Inject
    private AsyncFramework async;

    @Inject
    private Producer<byte[], byte[]> producer;

    @Inject
    private KafkaRouter router;

    @Inject
    private KafkaPartitioner partitioner;

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

    @Override
    public boolean isReady() {
        // TODO: how to check that producer is ready?
        return true;
    }

    private <T> List<KeyedMessage<byte[], byte[]>> messagesForMetrics(final Collection<Metric> metrics)
            throws Exception {
        final List<KeyedMessage<byte[], byte[]>> messages = new ArrayList<>(metrics.size());

        for (final Metric metric : metrics)
            messages.add(messageFor(metric));

        return messages;
    }

    private <T> List<KeyedMessage<byte[], byte[]>> messagesForEvents(final Collection<Event> events) throws Exception {
        final List<KeyedMessage<byte[], byte[]>> messages = new ArrayList<>(events.size());

        for (final Event event : events)
            messages.add(messageFor(event));

        return messages;
    }

    private KeyedMessage<byte[], byte[]> messageFor(final Metric metric) throws Exception {
        final String topic = router.route(metric);
        final String partition = partitioner.partition(metric);
        final byte[] payload = serializer.serialize(metric);
        return new KeyedMessage<>(topic, partition.getBytes(), payload);
    }

    private KeyedMessage<byte[], byte[]> messageFor(final Event event) throws Exception {
        final String topic = router.route(event);
        final String partition = partitioner.partition(event);
        final byte[] payload = serializer.serialize(event);
        return new KeyedMessage<byte[], byte[]>(topic, partition.getBytes(UTF8), payload);
    }
}