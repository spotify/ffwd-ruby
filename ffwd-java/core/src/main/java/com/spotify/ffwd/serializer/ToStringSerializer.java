package com.spotify.ffwd.serializer;

import lombok.extern.slf4j.Slf4j;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.google.common.base.Supplier;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;

@Slf4j
public class ToStringSerializer implements Serializer {
    @JsonCreator
    public ToStringSerializer() {
        log.warn("This serializer should only be used for debugging purposes");
    }

    @Override
    public byte[] serialize(Event event) throws Exception {
        return event.toString().getBytes();
    }

    @Override
    public byte[] serialize(Metric metric) throws Exception {
        return metric.toString().getBytes();
    }

    public static Supplier<Serializer> defaultSupplier() {
        return new Supplier<Serializer>() {
            @Override
            public Serializer get() {
                return new ToStringSerializer();
            }
        };
    }
}