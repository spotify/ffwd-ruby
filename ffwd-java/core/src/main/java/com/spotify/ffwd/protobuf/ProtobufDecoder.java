package com.spotify.ffwd.protobuf;

import io.netty.buffer.ByteBuf;
import io.netty.buffer.ByteBufInputStream;
import io.netty.channel.ChannelHandler.Sharable;
import io.netty.channel.ChannelHandlerContext;
import io.netty.handler.codec.MessageToMessageDecoder;

import java.io.InputStream;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import lombok.extern.slf4j.Slf4j;

import com.google.protobuf250.InvalidProtocolBufferException;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;
import com.spotify.ffwd.protocol0.Protocol0;

@Slf4j
@Sharable
public class ProtobufDecoder extends MessageToMessageDecoder<ByteBuf> {
    public static final int MAX_FRAME_SIZE = 0xffffff;

    @Override
    protected void decode(ChannelHandlerContext ctx, ByteBuf in, List<Object> out) throws Exception {
        while (in.readableBytes() >= 8) {
            decodeOne(ctx, in, out);
        }

        if (in.readableBytes() > 0)
            log.error("Garbage left in buffer, " + in.readableBytes() + " readable bytes have not been processed");
    }

    private void decodeOne(ChannelHandlerContext ctx, ByteBuf in, List<Object> out) throws Exception {
        final int version = (int) in.getUnsignedInt(0);
        final long totalLength = in.getUnsignedInt(4);

        if (totalLength > MAX_FRAME_SIZE) {
            log.error("Received frame with length (" + totalLength + ") larger than maximum allowed ( "
                    + MAX_FRAME_SIZE + ")");
            in.clear();
            return;
        }

        // datagram underflow
        if (in.readableBytes() < totalLength) {
            log.error("Received frame of shorter length (" + in.readableBytes() + ") than reported (" + totalLength
                    + ")");
            in.clear();
            return;
        }

        final int frameLength = (int) totalLength - 8;

        final ByteBuf buffer = ctx.alloc().buffer(frameLength);
        in.skipBytes(8);
        in.readBytes(buffer, frameLength);

        final Object frame;

        switch (version) {
        case 0:
            frame = decodeFrame0(buffer);
            break;
        default:
            throw new IllegalArgumentException("Unsupported protocol version: " + version);
        }

        if (frame != null)
            out.add(frame);
    }

    private Object decodeFrame0(ByteBuf buffer) throws Exception {
        final Protocol0.Message message;

        final InputStream inputStream = new ByteBufInputStream(buffer);

        try {
            message = Protocol0.Message.parseFrom(inputStream);
        } catch (final InvalidProtocolBufferException e) {
            throw new Exception("Invalid protobuf message", e);
        }

        if (message.hasEvent()) {
            return decodeEvent0(message.getEvent());
        }

        if (message.hasMetric()) {
            return decodeMetric0(message.getMetric());
        }

        return null;
    }

    private Object decodeMetric0(final Protocol0.Metric metric) {
        final String key = metric.hasKey() ? metric.getKey() : null;
        final double value = metric.hasValue() ? metric.getValue() : Double.NaN;
        final Date time = metric.hasTime() ? new Date(metric.getTime()) : null;
        final String host = metric.hasHost() ? metric.getHost() : null;
        final Set<String> tags = new HashSet<>(metric.getTagsList());
        final Map<String, String> attributes = convertAttributes0(metric.getAttributesList());
        final String proc = metric.hasProc() ? metric.getProc() : null;

        return new Metric(key, value, time, host, tags, attributes, proc);
    }

    private Map<String, String> convertAttributes0(List<Protocol0.Attribute> attributesList) {
        final Map<String, String> attributes = new HashMap<>();

        for (final Protocol0.Attribute a : attributesList)
            attributes.put(a.getKey(), a.getValue());

        return attributes;
    }

    private Object decodeEvent0(final Protocol0.Event event) {
        final String key = event.hasKey() ? event.getKey() : null;
        final double value = event.hasValue() ? event.getValue() : Double.NaN;
        final Date time = event.hasTime() ? new Date(event.getTime()) : null;
        final long ttl = event.hasTtl() ? event.getTtl() : 0;
        final String state = event.hasState() ? event.getState() : null;
        final String description = event.hasDescription() ? event.getDescription() : null;
        final String host = event.hasHost() ? event.getHost() : null;
        final Set<String> tags = new HashSet<>(event.getTagsList());
        final Map<String, String> attributes = convertAttributes0(event.getAttributesList());

        return new Event(key, value, time, ttl, state, description, host, tags, attributes);
    }
}
