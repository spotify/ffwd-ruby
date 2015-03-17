package com.spotify.ffwd.serializer;

import com.fasterxml.jackson.annotation.JsonTypeInfo;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;

@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, property = "type")
public interface Serializer {
    byte[] serialize(Event event) throws Exception;

    byte[] serialize(Metric metric) throws Exception;
}