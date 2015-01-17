package com.spotify.ffwd.protobuf;

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
import com.spotify.ffwd.protocol.ProtocolType;

public class ProtobufInputPlugin implements InputPlugin {
    private final Protocol protocol;

    @JsonCreator
    public ProtobufInputPlugin(@JsonProperty("protocol") Protocol protocol) {
        this.protocol = Optional.of(protocol).or(Protocol.defaultFor(ProtocolType.UDP, 19000));
    }

    @Override
    public Module module(final Key<PluginSource> key) {
        return new PrivateModule() {
            @Override
            protected void configure() {
                bind(ProtobufUDPProtocolServer.class).in(Scopes.SINGLETON);
                bind(key).to(ProtobufPluginSource.class);
                expose(key);
            }
        };
    }
}
