package com.spotify.ffwd.kafka;

import java.util.ArrayList;
import java.util.List;

import kafka.javaapi.producer.Producer;
import kafka.producer.KeyedMessage;

import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;
import com.spotify.ffwd.output.AbstractPluginSink;

public class KafkaPluginSink extends AbstractPluginSink {

    private final Producer<String, String> producer;

    private final KafkaRouter router;

    public KafkaPluginSink(final Producer<String, String> producer, final Integer flushInterval, final KafkaRouter router) {
        super(flushInterval);
        this.producer = producer;
        this.router = router;
    }

    @Override
    public void doSendEvent(final Event event) {
        producer.send(createMessage(event));
    }

    @Override
    public void doSendMetric(final Metric metric) {
        producer.send(createMessage(metric));
    }

    @Override
    public void doSendAllEvents(final List<Event> events) {
        producer.send(createMessages(events));
    }

    @Override
    public void doSendAllMetrics(final List<Metric> metrics) {
        producer.send(createMessages(metrics));
    }

    private <T> List<KeyedMessage<String, String>> createMessages(final List<T> elements) {
        final List<KeyedMessage<String, String>> messages = new ArrayList<KeyedMessage<String,String>>();
        for (final T e : elements) {
            messages.add(createMessage(e));
        }
        return messages;
    }

    private <T> KeyedMessage<String, String> createMessage(final T element) {
        String topic = null;
        if (element instanceof Event) {
            topic = router.getEventTopic((Event) element);
        } else if (element instanceof Metric) {
            topic = router.getMetricTopic((Metric) element);
        } else {
            throw new IllegalArgumentException("Can only create kafka message for events and metrics. Given element: " + element);
        }
        return new KeyedMessage<String, String>(topic, element.toString());
    }
}