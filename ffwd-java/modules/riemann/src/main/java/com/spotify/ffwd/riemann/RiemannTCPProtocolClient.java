package com.spotify.ffwd.riemann;

import io.netty.channel.Channel;
import io.netty.channel.ChannelInitializer;

import com.spotify.ffwd.protocol.ProtocolClient;

/**
 * riemann client to handle individual events.
 */
public class RiemannTCPProtocolClient implements ProtocolClient {
    @Override
    public ChannelInitializer<Channel> initializer() {
        return new ChannelInitializer<Channel>() {
            @Override
            protected void initChannel(Channel ch) throws Exception {
            }
        };
    }
}