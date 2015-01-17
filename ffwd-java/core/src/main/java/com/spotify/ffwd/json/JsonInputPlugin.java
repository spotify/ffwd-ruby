package com.spotify.ffwd.json;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.google.common.base.Optional;
import com.google.inject.Key;
import com.google.inject.Module;
import com.google.inject.PrivateModule;
import com.google.inject.Scopes;
import com.spotify.ffwd.input.InputPlugin;
import com.spotify.ffwd.input.PluginSource;
import com.spotify.ffwd.protocol.Protocol;
import com.spotify.ffwd.protocol.ProtocolFactory;
import com.spotify.ffwd.protocol.ProtocolServer;
import com.spotify.ffwd.protocol.ProtocolType;

public class JsonInputPlugin implements InputPlugin {
    private static final ProtocolType DEFAULT_PROTOCOL = ProtocolType.UDP;
    private static final int DEFAULT_PORT = 19090;

    private static final String FRAME = "frame";
    private static final String LINE = "line";

    public static final String DEFAULT_DELIMITER = FRAME;

    private final Protocol protocol;
    private final Class<? extends ProtocolServer> protocolServer;

    @JsonCreator
    public JsonInputPlugin(@JsonProperty("protocol") ProtocolFactory protocol,
            @JsonProperty("delimiter") String delimiter) {
        this.protocol = Optional.fromNullable(protocol).or(ProtocolFactory.defaultFor())
                .protocol(DEFAULT_PROTOCOL, DEFAULT_PORT);
        this.protocolServer = parseProtocolServer(Optional.fromNullable(delimiter).or(defaultDelimiter()));
    }

    private String defaultDelimiter() {
        if (protocol.getType() == ProtocolType.TCP)
            return LINE;

        if (protocol.getType() == ProtocolType.UDP)
            return FRAME;

        return FRAME;
    }

    private Class<? extends ProtocolServer> parseProtocolServer(String delimiter) {
        if (FRAME.equals(delimiter)) {
            if (protocol.getType() == ProtocolType.TCP)
                throw new IllegalArgumentException("frame-based decoding is not suitable for TCP");

            return JsonFrameProtocolServer.class;
        }

        if (LINE.equals(delimiter))
            return JsonLineProtocolServer.class;

        return defaultProtocolServer();
    }

    private Class<? extends ProtocolServer> defaultProtocolServer() {
        if (protocol.getType() == ProtocolType.TCP)
            return JsonLineProtocolServer.class;

        return JsonFrameProtocolServer.class;
    }

    @Override
    public Module module(final Key<PluginSource> key) {
        return new PrivateModule() {
            @Override
            protected void configure() {
                bind(JsonObjectMapperDecoder.class).in(Scopes.SINGLETON);
                bind(Protocol.class).toInstance(protocol);
                bind(ProtocolServer.class).to(protocolServer).in(Scopes.SINGLETON);
                bind(key).to(JsonPluginSource.class).in(Scopes.SINGLETON);
                expose(key);
            }
        };
    }
}
