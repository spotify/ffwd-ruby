package com.spotify.ffwd.kafka;

import java.nio.ByteBuffer;
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
import com.google.inject.Provides;
import com.spotify.ffwd.output.BatchedPluginSink;
import com.spotify.ffwd.output.FlushingPluginSink;
import com.spotify.ffwd.output.OutputPlugin;
import com.spotify.ffwd.output.PluginSink;

public class KafkaOutputPlugin implements OutputPlugin {
    private final KafkaRouter router;
    private final Map<String, String> properties;
    private final Long flushInterval;

    @JsonCreator
    public KafkaOutputPlugin(@JsonProperty("producer") Map<String, String> properties,
            @JsonProperty("flushInterval") Long flushInterval, @JsonProperty("router") KafkaRouter router) {
        this.router = Optional.fromNullable(router).or(new KafkaRouter());
        this.flushInterval = Optional.fromNullable(flushInterval).orNull();
        this.properties = Optional.fromNullable(properties).or(new HashMap<String, String>());
    }

    @Override
    public Module module(final Key<PluginSink> key) {
        return new PrivateModule() {
            @Provides
            public Producer<String, ByteBuffer> producer() {
                final Properties props = new Properties();
                props.putAll(properties);
                final ProducerConfig config = new ProducerConfig(props);
                return new Producer<String, ByteBuffer>(config);
            }

            @Override
            protected void configure() {
                bind(KafkaRouter.class).toInstance(router);

                if (flushInterval != null) {
                    bind(BatchedPluginSink.class).to(KafkaPluginSink.class);
                    bind(key).toInstance(new FlushingPluginSink(flushInterval));
                } else {
                    bind(key).to(KafkaPluginSink.class);
                }

                expose(key);
            }
        };
    }
}