package com.spotify.ffwd.kafka;

import java.util.HashMap;
import java.util.Map;
import java.util.Properties;

import kafka.javaapi.producer.Producer;
import kafka.producer.ProducerConfig;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.google.common.base.Optional;
import com.google.inject.Key;
import com.google.inject.Module;
import com.google.inject.PrivateModule;
import com.spotify.ffwd.output.OutputPlugin;
import com.spotify.ffwd.output.PluginSink;

public class KafkaOutputPlugin implements OutputPlugin {

    private final Producer<String, String> producer;
    private final String topic;
    private final Integer flushInterval;

    @JsonCreator
    public KafkaOutputPlugin(@JsonProperty("producer") final Map<String, String> producerProps, @JsonProperty("topic") final String topic, @JsonProperty("flushInterval") final Integer flushInterval) {
        this.flushInterval = Optional.fromNullable(flushInterval).orNull();

        if (topic == null || topic.isEmpty()) {
            throw new IllegalArgumentException("Kafka topic must be specified.");
        }
        this.topic = topic;

        // The reason why we are not directly getting a Properties object is that the YAML parser parses numbers into integers
        // and Kafka "PropducerConfig" throws NumberFormatExcption if you don't pass numbers as strings. Strange!
        final Map<String, String> propMap = Optional.fromNullable(producerProps).or(new HashMap<String, String>());
        final Properties props = new Properties();
        props.putAll(propMap);

        final ProducerConfig config = new ProducerConfig(props);

        producer = new Producer<String, String>(config);
    }

    @Override
    public Module module(final Key<PluginSink> key) {
        return new PrivateModule() {
            @Override
            protected void configure() {
                final PluginSink sink = new KafkaPluginSink(producer, topic, flushInterval);
                bind(key).toInstance(sink);
                expose(key);
            }
        };
    }
}