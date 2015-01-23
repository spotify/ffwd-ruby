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

    private final String topic;

    public KafkaPluginSink(final Producer<String, String> producer, final String topic, final Integer flushInterval) {
        super(flushInterval);
        this.producer = producer;
        this.topic = topic;
    }

    @Override
    public void doSendEvent(final Event event) {
        producer.send(createMessage(topic, event));
    }

    @Override
    public void doSendMetric(final Metric metric) {
        producer.send(createMessage(topic, metric));
    }

    @Override
    public void doSendAllEvents(final List<Event> events) {
        producer.send(createMessages(topic, events));
    }

    @Override
    public void doSendAllMetrics(final List<Metric> metrics) {
        producer.send(createMessages(topic, metrics));
    }

    private <T> List<KeyedMessage<String, String>> createMessages(final String topic, final List<T> elements) {
        final List<KeyedMessage<String, String>> messages = new ArrayList<KeyedMessage<String,String>>();
        for (final T e : elements) {
            messages.add(createMessage(topic, e));
        }
        return messages;
    }

    private <T> KeyedMessage<String, String> createMessage(final String topic, final T element) {
        return new KeyedMessage<String, String>(topic, element.toString());
    }
}