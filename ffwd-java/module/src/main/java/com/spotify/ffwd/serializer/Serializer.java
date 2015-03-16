package com.spotify.ffwd.serializer;

import java.nio.ByteBuffer;

import com.fasterxml.jackson.annotation.JsonTypeInfo;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;

@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, property = "type")
public interface Serializer {
    ByteBuffer serialize(Event event);

    ByteBuffer serialize(Metric metric);
}