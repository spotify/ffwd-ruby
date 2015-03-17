package com.spotify.ffwd.riemann;

import io.netty.channel.Channel;
import io.netty.channel.ChannelInboundHandler;
import io.netty.channel.ChannelInitializer;

import com.google.inject.Inject;
import com.spotify.ffwd.protocol.ProtocolServer;

/**
 * Decode a stream of data which is length-prefixed.
 *
 * Should only be used with TCP-based protocols.
 *
 * @author udoprog
 */
public class RiemannTCPProtocolServer implements ProtocolServer {
    @Inject
    private ChannelInboundHandler handler;

    @Inject
    private RiemannDecoder decoder;

    private final RiemannResponder responder = new RiemannResponder();

    @Override
    public final ChannelInitializer<Channel> initializer() {
        return new ChannelInitializer<Channel>() {
            @Override
            protected void initChannel(Channel ch) throws Exception {
                final RiemannFrameDecoder frameDecoder = new RiemannFrameDecoder();
                ch.pipeline().addLast(frameDecoder, decoder, responder, handler);
            }
        };
    }
}
