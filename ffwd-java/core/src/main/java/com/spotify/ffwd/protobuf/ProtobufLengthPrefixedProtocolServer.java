package com.spotify.ffwd.protobuf;

import io.netty.channel.Channel;
import io.netty.channel.ChannelInboundHandler;
import io.netty.channel.ChannelInitializer;
import io.netty.handler.codec.LengthFieldBasedFrameDecoder;

import com.google.inject.Inject;
import com.spotify.ffwd.protocol.ProtocolServer;

/**
 * Decode a stream of data which is length-prefixed.
 *
 * Should only be used with TCP-based protocols.
 * 
 * @author udoprog
 */
public class ProtobufLengthPrefixedProtocolServer implements ProtocolServer {
    private final int MAX_LENGTH = 0xffffff;

    @Inject
    private ChannelInboundHandler handler;

    @Inject
    private ProtobufDecoder decoder;

    @Override
    public final ChannelInitializer<Channel> initializer() {
        return new ChannelInitializer<Channel>() {
            @Override
            protected void initChannel(Channel ch) throws Exception {
                ch.pipeline().addLast(new LengthFieldBasedFrameDecoder(MAX_LENGTH, 0, 4), decoder, handler);
            }
        };
    }
}
