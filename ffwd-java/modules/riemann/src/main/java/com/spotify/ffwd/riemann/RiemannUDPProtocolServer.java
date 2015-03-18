package com.spotify.ffwd.riemann;

import io.netty.channel.Channel;
import io.netty.channel.ChannelInboundHandler;
import io.netty.channel.ChannelInitializer;

import com.google.inject.Inject;
import com.spotify.ffwd.protocol.ProtocolServer;

/**
 * Decode individual frames, should only be used with UDP protocols.
 *
 * @author udoprog
 */
public class RiemannUDPProtocolServer implements ProtocolServer {
    @Inject
    private ChannelInboundHandler handler;

    @Inject
    private RiemannMessageDecoder messageDecoder;

    @Inject
    private RiemannDatagramDecoder datagramDecoder;

    @Override
    public final ChannelInitializer<Channel> initializer() {
        return new ChannelInitializer<Channel>() {
            @Override
            protected void initChannel(Channel ch) throws Exception {
                ch.pipeline().addLast(datagramDecoder, messageDecoder, handler);
            }
        };
    }
}
