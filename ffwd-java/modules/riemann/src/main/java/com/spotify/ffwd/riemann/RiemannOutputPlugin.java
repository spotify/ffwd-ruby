package com.spotify.ffwd.riemann;

import lombok.extern.slf4j.Slf4j;

import org.slf4j.Logger;

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
import com.spotify.ffwd.protocol.ProtocolPluginSink;
import com.spotify.ffwd.protocol.ProtocolType;
import com.spotify.ffwd.protocol.RetryPolicy;

@Slf4j
public class RiemannOutputPlugin implements OutputPlugin {
    private static final ProtocolType DEFAULT_PROTOCOL = ProtocolType.TCP;
    private static final int DEFAULT_PORT = 5555;
    private static final long DEFAULT_FLUSH_INTERVAL = 0; // TimeUnit.MILLISECONDS.convert(10, TimeUnit.SECONDS);

    private final Long flushInterval;
    private final Protocol protocol;
    private final Class<? extends ProtocolClient> protocolClient;
    private final RetryPolicy retry;

    @JsonCreator
    public RiemannOutputPlugin(@JsonProperty("flushInterval") Long flushInterval,
            @JsonProperty("protocol") ProtocolFactory protocol, @JsonProperty("retry") RetryPolicy retry) {
        this.flushInterval = Optional.fromNullable(flushInterval).or(DEFAULT_FLUSH_INTERVAL);
        this.protocol = Optional.fromNullable(protocol).or(ProtocolFactory.defaultFor())
                .protocol(DEFAULT_PROTOCOL, DEFAULT_PORT);
        this.protocolClient = parseProtocolClient();
        this.retry = Optional.fromNullable(retry).or(new RetryPolicy.Exponential());
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
                bind(RiemannMessageDecoder.class).in(Scopes.SINGLETON);
                bind(ProtocolClient.class).to(protocolClient).in(Scopes.SINGLETON);
                bind(RetryPolicy.class).toInstance(retry);
                bind(Logger.class).toInstance(log);

                if (flushInterval != null && flushInterval > 0) {
                    bind(BatchedPluginSink.class).to(ProtocolPluginSink.class).in(Scopes.SINGLETON);
                    bind(key).toInstance(new FlushingPluginSink(flushInterval));
                } else {
                    bind(key).to(ProtocolPluginSink.class).in(Scopes.SINGLETON);
                }

                expose(key);
            }
        };
    }
}
