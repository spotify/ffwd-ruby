package com.spotify.ffwd.riemann;

import io.netty.buffer.ByteBuf;
import io.netty.buffer.ByteBufInputStream;
import io.netty.channel.ChannelHandler.Sharable;
import io.netty.channel.ChannelHandlerContext;
import io.netty.handler.codec.CorruptedFrameException;
import io.netty.handler.codec.MessageToMessageDecoder;

import java.io.InputStream;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import com.aphyr.riemann.Proto;
import com.google.common.collect.ImmutableList;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.protobuf250.InvalidProtocolBufferException;

@Sharable
public class RiemannDecoder extends MessageToMessageDecoder<RiemannFrame> {
    @Override
    protected void decode(ChannelHandlerContext ctx, RiemannFrame in, List<Object> out) throws Exception {
        decodeOne(ctx, in, out);
    }

    private void decodeOne(ChannelHandlerContext ctx, RiemannFrame in, List<Object> out) throws Exception {
        final List<Object> frames;

        switch (in.getVersion()) {
        case 0:
            frames = decode0(in.getBuffer());
            break;
        default:
            throw new CorruptedFrameException("invalid version: " + in.getVersion());
        }

        if (frames != null) {
            for (final Object frame : frames)
                out.add(frame);
        }
    }

    private List<Object> decode0(ByteBuf buffer) throws Exception {
        final Proto.Msg message;

        final InputStream inputStream = new ByteBufInputStream(buffer);

        try {
            message = Proto.Msg.parseFrom(inputStream);
        } catch (final InvalidProtocolBufferException e) {
            throw new Exception("Invalid protobuf message", e);
        }

        final List<com.aphyr.riemann.Proto.Event> source = message.getEventsList();

        if (source.isEmpty())
            return ImmutableList.of();

        final List<Object> events = new ArrayList<>();

        for (Proto.Event e : source)
            events.add(decodeEvent0(e));

        return events;
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
