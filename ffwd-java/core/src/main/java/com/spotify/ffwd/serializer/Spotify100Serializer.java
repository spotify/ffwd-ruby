package com.spotify.ffwd.serializer;

import java.io.ByteArrayOutputStream;
import java.util.Map;

import lombok.Data;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonTypeName;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.inject.Inject;
import com.google.inject.name.Named;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;

@JsonTypeName("spotify100")
public class Spotify100Serializer implements Serializer {
    public static final String SCHEMA_VERSION = "1.0.0";

    @Inject
    @Named("application/json")
    private ObjectMapper mapper;

    @Data
    public static class Spotify100Metric {
        private final String version = SCHEMA_VERSION;
        private final String key;
        private final String host;
        private final Long time;
        private final Map<String, String> attributes;
        private final Double value;
    }

    @Data
    public static class Spotify100Event {
        private final String version = SCHEMA_VERSION;
        private final String key;
        private final String host;
        private final Long time;
        private final Map<String, String> attributes;
        private final Double value;
    }

    @JsonCreator
    public Spotify100Serializer() {
    }

    @Override
    public byte[] serialize(Event source) throws Exception {
        final Spotify100Event e = new Spotify100Event(source.getKey(), source.getHost(), source.getTime().getTime(),
                source.getAttributes(), source.getValue());
        final ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
        mapper.writeValue(outputStream, e);
        return outputStream.toByteArray();
    }

    @Override
    public byte[] serialize(Metric source) throws Exception {
        final Spotify100Metric m = new Spotify100Metric(source.getKey(), source.getHost(), source.getTime().getTime(),
                source.getAttributes(), source.getValue());
        final ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
        mapper.writeValue(outputStream, m);
        return outputStream.toByteArray();
    }
}