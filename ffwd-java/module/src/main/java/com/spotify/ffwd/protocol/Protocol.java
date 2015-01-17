package com.spotify.ffwd.protocol;

import java.net.InetSocketAddress;

import lombok.Data;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.google.common.base.Supplier;

@Data
public class Protocol {
    public static final String DEFAULT_HOST = "127.0.0.1";

    private final ProtocolType type;
    private final InetSocketAddress address;

    @JsonCreator
    public static Protocol build(String type, String host, Integer port, ProtocolType defaultType, int defaultPort) {
        if (type == null || port == null)
            return new Protocol(defaultType, new InetSocketAddress(DEFAULT_HOST, defaultPort));

        final ProtocolType t = parseProtocolType(type, defaultType);
        final InetSocketAddress address = parseSocketAddress(host, port, defaultPort);
        return new Protocol(t, address);
    }

    private static InetSocketAddress parseSocketAddress(String host, Integer port, int defaultPort) {
        if (host == null)
            host = DEFAULT_HOST;

        if (port == null)
            port = defaultPort;

        return new InetSocketAddress(host, port);
    }

    private static ProtocolType parseProtocolType(String type, ProtocolType defaultType) {
        if (type == null)
            return defaultType;

        if (ProtocolType.TCP.name().equals(type))
            return ProtocolType.TCP;

        if (ProtocolType.UDP.name().equals(type))
            return ProtocolType.UDP;

        throw new IllegalArgumentException("Invalid protocol type: " + type);
    }

    public static Supplier<Protocol> defaultFor(final ProtocolType type, final int port) {
        return new Supplier<Protocol>() {
            @Override
            public Protocol get() {
                return new Protocol(type, new InetSocketAddress(DEFAULT_HOST, port));
            }
        };
    }
}