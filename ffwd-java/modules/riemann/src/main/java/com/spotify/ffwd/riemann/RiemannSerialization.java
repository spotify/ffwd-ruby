package com.spotify.ffwd.riemann;

import io.netty.buffer.ByteBuf;
import io.netty.buffer.ByteBufInputStream;
import io.netty.buffer.ByteBufOutputStream;
import io.netty.buffer.Unpooled;

import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import com.aphyr.riemann.Proto;
import com.google.common.collect.ImmutableList;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;
import com.spotify.ffwd.protobuf250.InvalidProtocolBufferException;

public class RiemannSerialization {
    public Proto.Msg parse0(ByteBuf buffer) throws IOException {
        final InputStream inputStream = new ByteBufInputStream(buffer);

        try {
            return Proto.Msg.parseFrom(inputStream);
        } catch (final InvalidProtocolBufferException e) {
            throw new IOException("Invalid protobuf message", e);
        }
    }

    public List<Object> decode0(Proto.Msg message) throws IOException {
        final List<com.aphyr.riemann.Proto.Event> source = message.getEventsList();

        if (source.isEmpty())
            return ImmutableList.of();

        final List<Object> events = new ArrayList<>();

        for (Proto.Event e : source)
            events.add(decodeEvent0(e));

        return events;
    }

    public ByteBuf encode0(Object msg) throws IOException {
        return encodeAll0(ImmutableList.of(msg));
    }

    public ByteBuf encodeAll0(Collection<Object> messages) throws IOException {
        final Proto.Msg.Builder builder = Proto.Msg.newBuilder();

        int valid = 0;

        for (final Object d : messages) {
            if (d instanceof Metric) {
                builder.addEvents(encodeMetric0((Metric) d));
                ++valid;
            } else if (d instanceof Event) {
                builder.addEvents(encodeEvent0((Event) d));
                ++valid;
            }
        }

        if (valid <= 0)
            return null;

        final Proto.Msg m = builder.build();

        final ByteBuf work = Unpooled.buffer();

        try (final ByteBufOutputStream output = new ByteBufOutputStream(work)) {
            m.writeTo(output);

            final ByteBuf result = Unpooled.buffer();

            result.writeInt(work.writerIndex());
            result.writeBytes(work);

            return result;
        } finally {
            work.release();
        }
    }

    private Proto.Event.Builder encodeMetric0(final Metric d) {
        final Proto.Event.Builder b = Proto.Event.newBuilder();

        if (d.getKey() != null)
            b.setService(d.getKey());

        if (d.getHost() != null)
            b.setHost(d.getHost());

        b.setMetricD(d.getValue());
        b.addAllAttributes(convertAttributes0(d.getAttributes()));
        b.addAllTags(d.getTags());
        b.setTime(d.getTime().getTime());

        return b;
    }

    private Proto.Event.Builder encodeEvent0(final Event d) {
        final Proto.Event.Builder b = Proto.Event.newBuilder();
        if (d.getKey() != null)
            b.setService(d.getKey());

        if (d.getHost() != null)
            b.setHost(d.getHost());

        b.setMetricD(d.getValue());
        b.addAllAttributes(convertAttributes0(d.getAttributes()));
        b.addAllTags(d.getTags());
        b.setTime(d.getTime().getTime());

        if (d.getDescription() != null)
            b.setDescription(d.getDescription());

        b.setTtl(d.getTtl());

        if (d.getState() != null)
            b.setState(d.getState());

        return b;
    }

    private Iterable<? extends Proto.Attribute> convertAttributes0(Map<String, String> source) {
        final List<Proto.Attribute> attributes = new ArrayList<>();

        for (final Map.Entry<String, String> e : source.entrySet())
            attributes.add(Proto.Attribute.newBuilder().setKey(e.getKey()).setValue(e.getValue()).build());

        return attributes;
    }

    private Map<String, String> convertAttributes0(List<Proto.Attribute> attributesList) {
        final Map<String, String> attributes = new HashMap<>();

        for (final Proto.Attribute a : attributesList)
            attributes.put(a.getKey(), a.getValue());

        return attributes;
    }

    private double convertValue0(Proto.Event e) {
        if (e.hasMetricD())
            return e.getMetricD();

        if (e.hasMetricSint64())
            return e.getMetricSint64();

        if (e.hasMetricF())
            return e.getMetricF();

        return Double.NaN;
    }

    private Object decodeEvent0(final Proto.Event event) {
        final String service = event.hasService() ? event.getService() : null;
        final Date time = event.hasTime() ? new Date(event.getTime()) : null;
        final long ttl = (long) (event.hasTtl() ? event.getTtl() : 0f);
        final String state = event.hasState() ? event.getState() : null;
        final String description = event.hasDescription() ? event.getDescription() : null;
        final String host = event.hasHost() ? event.getHost() : null;
        final Set<String> tags = new HashSet<>(event.getTagsList());
        final Map<String, String> attributes = convertAttributes0(event.getAttributesList());

        final double value = convertValue0(event);

        return new Event(service, value, time, ttl, state, description, host, tags, attributes);
    }
}
