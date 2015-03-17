package com.spotify.ffwd.riemann;

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

public class RiemannInputPlugin implements InputPlugin {
    private static final ProtocolType DEFAULT_PROTOCOL = ProtocolType.TCP;
    private static final int DEFAULT_PORT = 5555;

    private final Protocol protocol;
    private final Class<? extends ProtocolServer> protocolServer;

    @JsonCreator
    public RiemannInputPlugin(@JsonProperty("protocol") ProtocolFactory protocol) {
        this.protocol = Optional.of(protocol).or(ProtocolFactory.defaultFor()).protocol(DEFAULT_PROTOCOL, DEFAULT_PORT);
        this.protocolServer = parseProtocolServer();
    }

    private Class<? extends ProtocolServer> parseProtocolServer() {
        if (protocol.getType() == ProtocolType.UDP)
            return RiemannUDPProtocolServer.class;

        if (protocol.getType() == ProtocolType.TCP)
            return RiemannTCPProtocolServer.class;

        throw new IllegalArgumentException("Protocol not supported: " + protocol.getType());
    }

    @Override
    public Module module(final Key<PluginSource> key) {
        return new PrivateModule() {
            @Override
            protected void configure() {
                bind(ProtocolServer.class).to(protocolServer).in(Scopes.SINGLETON);
                bind(Protocol.class).toInstance(protocol);
                bind(RiemannDecoder.class).in(Scopes.SINGLETON);

                bind(key).to(RiemannPluginSource.class).in(Scopes.SINGLETON);
                expose(key);
            }
        };
    }
}
