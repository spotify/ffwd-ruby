package com.spotify.ffwd.json;

import io.netty.channel.Channel;
import io.netty.channel.ChannelInboundHandler;
import io.netty.channel.ChannelInitializer;
import io.netty.handler.codec.LineBasedFrameDecoder;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.inject.Inject;
import com.google.inject.name.Named;
import com.spotify.ffwd.protocol.ProtocolServer;

public class JsonLineProtocolServer implements ProtocolServer {
    public static final int MAX_LINE = 0xffff;

    @Inject
    @Named("application/json")
    private ObjectMapper mapper;

    @Inject
    private ChannelInboundHandler handler;

    @Inject
    private JsonObjectMapperDecoder decoder;

    @Override
    public final ChannelInitializer<Channel> initializer() {
        return new ChannelInitializer<Channel>() {
            @Override
            protected void initChannel(Channel ch) throws Exception {
                ch.pipeline().addLast(new LineBasedFrameDecoder(MAX_LINE));
                ch.pipeline().addLast(decoder, handler);
            }
        };
    }
}