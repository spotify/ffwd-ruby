package com.spotify.ffwd.serializer;

import java.nio.ByteBuffer;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonTypeName;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;

@JsonTypeName("spotify100")
public class Spotify100Serializer implements Serializer {
    @JsonCreator
    public Spotify100Serializer() {
    }

    @Override
    public ByteBuffer serialize(Event event) {
        // TODO Auto-generated method stub
        return null;
    }

    @Override
    public ByteBuffer serialize(Metric metric) {
        // TODO Auto-generated method stub
        return null;
    }
}