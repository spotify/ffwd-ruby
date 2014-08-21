package com.spotify.ffwd.plugin.ffwd;

import io.netty.buffer.ByteBuf;
import io.netty.buffer.ByteBufAllocator;
import io.netty.buffer.ByteBufInputStream;

import java.io.InputStream;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.google.protobuf250.InvalidProtocolBufferException;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;
import com.spotify.ffwd.protocol0.Protocol0;

public class FastForwardDecoder {
	public static final long MAX_FRAME_SIZE = 65536;

	public static void decode(ByteBufAllocator allocator, ByteBuf in,
			List<Object> out) throws Exception {
		while (in.readableBytes() >= 8) {
			final int version = (int) in.getUnsignedInt(0);
			final long totalLength = in.getUnsignedInt(4);

			if (totalLength > MAX_FRAME_SIZE) {
				throw new Exception(
						"Received frame is larger than maximum allowed: "
								+ totalLength);
			}

			if (in.readableBytes() < totalLength) {
				break;
			}

			final int frameLength = (int) totalLength - 8;

			final ByteBuf buffer = allocator.buffer(frameLength);
			in.skipBytes(8);
			in.readBytes(buffer, frameLength);

			final Object frame;

			switch (version) {
			case 0:
				frame = decodeFrame0(buffer);
				break;
			default:
				throw new Exception("Unsupported protocol version: " + version);
			}

			if (frame != null) {
				out.add(frame);
			}
		}
	}

	private static Object decodeFrame0(ByteBuf buffer) throws Exception {
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

	private static Object decodeMetric0(final Protocol0.Metric metric) {
		final Date time;

		if (metric.hasTime()) {
			time = new Date(metric.getTime());
		} else {
			time = null;
		}

		final String host;

		if (metric.hasHost()) {
			host = metric.getHost();
		} else {
			host = null;
		}

		final List<String> tags = metric.getTagsList();
		final Map<String, String> attributes = convertAttributes0(metric
				.getAttributesList());

		final String proc;

		if (metric.hasProc()) {
			proc = metric.getProc();
		} else {
			proc = null;
		}

		return new Metric(metric.getKey(), metric.getValue(), time, host, tags,
				attributes, proc);
	}

	private static Map<String, String> convertAttributes0(
			List<Protocol0.Attribute> attributesList) {
		final Map<String, String> attributes = new HashMap<>();

		for (final Protocol0.Attribute a : attributesList) {
			attributes.put(a.getKey(), a.getValue());
		}

		return attributes;
	}

	private static Object decodeEvent0(final Protocol0.Event event) {
		final Date time;

		if (event.hasTime()) {
			time = new Date(event.getTime());
		} else {
			time = null;
		}

		final Long ttl;

		if (event.hasTtl()) {
			ttl = event.getTtl();
		} else {
			ttl = null;
		}

		final String state;

		if (event.hasState()) {
			state = event.getState();
		} else {
			state = null;
		}

		final String description;

		if (event.hasDescription()) {
			description = event.getDescription();
		} else {
			description = null;
		}

		final String host;

		if (event.hasHost()) {
			host = event.getHost();
		} else {
			host = null;
		}

		final List<String> tags = event.getTagsList();
		final Map<String, String> attributes = convertAttributes0(event
				.getAttributesList());

		return new Event(event.getKey(), event.getValue(), time, ttl, state,
				description, host, tags, attributes);
	}
}
