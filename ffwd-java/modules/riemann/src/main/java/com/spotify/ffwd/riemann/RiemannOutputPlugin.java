package com.spotify.ffwd.riemann;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.google.common.base.Optional;
import com.google.inject.Key;
import com.google.inject.Module;
import com.google.inject.PrivateModule;
import com.google.inject.Scopes;
import com.spotify.ffwd.output.BatchedPluginSink;
import com.spotify.ffwd.output.FlushingPluginSink;
import com.spotify.ffwd.output.OutputPlugin;
import com.spotify.ffwd.output.PluginSink;
import com.spotify.ffwd.protocol.Protocol;
import com.spotify.ffwd.protocol.ProtocolClient;
import com.spotify.ffwd.protocol.ProtocolFactory;
import com.spotify.ffwd.protocol.ProtocolType;

public class RiemannOutputPlugin implements OutputPlugin {
    private static final ProtocolType DEFAULT_PROTOCOL = ProtocolType.TCP;
    private static final int DEFAULT_PORT = 5555;

    private final Long flushInterval;
    private final Protocol protocol;
    private final Class<? extends ProtocolClient> protocolClient;

    @JsonCreator
    public RiemannOutputPlugin(@JsonProperty("flushInterval") Long flushInterval,
            @JsonProperty("protocol") ProtocolFactory protocol) {
        this.flushInterval = flushInterval;
        this.protocol = Optional.of(protocol).or(ProtocolFactory.defaultFor()).protocol(DEFAULT_PROTOCOL, DEFAULT_PORT);
        this.protocolClient = parseProtocolClient();
    }

    private Class<? extends ProtocolClient> parseProtocolClient() {
        if (protocol.getType() == ProtocolType.TCP)
            return RiemannTCPProtocolClient.class;

        throw new IllegalArgumentException("Protocol not supported: " + protocol.getType());
    }

    @Override
    public Module module(final Key<PluginSink> key) {
        return new PrivateModule() {
            @Override
            protected void configure() {
                bind(Protocol.class).toInstance(protocol);
                bind(RiemannDecoder.class).in(Scopes.SINGLETON);
                bind(ProtocolClient.class).to(protocolClient).in(Scopes.SINGLETON);

                if (flushInterval != null) {
                    bind(BatchedPluginSink.class).to(RiemannPluginSink.class);
                    bind(key).toInstance(new FlushingPluginSink(flushInterval));
                } else {
                    bind(key).to(RiemannPluginSink.class);
                }

                expose(key);
            }
        };
    }
}
