package com.spotify.ffwd.protocol;

import java.net.InetSocketAddress;

import lombok.Data;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.google.common.base.Supplier;

/**
 * Data type suitable for building using a @JsonCreator block.
 *
 * @author udoprog
 */
@Data
public class ProtocolFactory {
    public static final String DEFAULT_HOST = "127.0.0.1";

    private final String type;
    private final String host;
    private final Integer port;

    @JsonCreator
    public static ProtocolFactory build(@JsonProperty("type") String type, @JsonProperty("host") String host,
            @JsonProperty("port") Integer port) {
        return new ProtocolFactory(type, host, port);
    }

    /**
     * Build a default instance of {@link ProtocolFactory}.
     * 
     * @return
     */
    public static Supplier<ProtocolFactory> defaultFor() {
        return new Supplier<ProtocolFactory>() {
            @Override
            public ProtocolFactory get() {
                return new ProtocolFactory(null, null, null);
            }
        };
    }

    /**
     * @see #protocol(ProtocolType, int, String)
     */
    public Protocol protocol(ProtocolType defaultType, int defaultPort) {
        return protocol(defaultType, defaultPort, DEFAULT_HOST);
    }

    /**
     * Build a new protocol instance with the given defaults if they are missing.
     *
     * @param defaultType Default type.
     * @param defaultPort Default port.
     * @param defaultHost Default host.
     * @return
     */
    public Protocol protocol(ProtocolType defaultType, int defaultPort, String defaultHost) {
        final ProtocolType t = parseProtocolType(type, defaultType);
        final InetSocketAddress address = parseSocketAddress(host, port, defaultPort, defaultHost);
        return new Protocol(t, address);
    }

    private InetSocketAddress parseSocketAddress(String host, Integer port, int defaultPort, String defaultHost) {
        if (host == null)
            host = defaultHost;

        if (port == null)
            port = defaultPort;

        return new InetSocketAddress(host, port);
    }

    private ProtocolType parseProtocolType(String type, ProtocolType defaultType) {
        if (type == null)
            return defaultType;

        type = type.toUpperCase();

        if (ProtocolType.TCP.name().equals(type))
            return ProtocolType.TCP;

        if (ProtocolType.UDP.name().equals(type))
            return ProtocolType.UDP;

        throw new IllegalArgumentException("Invalid protocol type: " + type);
    }
}