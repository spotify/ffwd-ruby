package com.spotify.ffwd.riemann;

import io.netty.channel.Channel;
import io.netty.channel.ChannelInitializer;

import com.spotify.ffwd.protocol.ProtocolClient;

/**
 * riemann client to handle batches of events.
 *
 * events and metrics are expected to arrive in lists.
 */
public class RiemannTCPFlushingProtocolClient implements ProtocolClient {
    @Override
    public ChannelInitializer<Channel> initializer() {
        return new ChannelInitializer<Channel>() {
            @Override
            protected void initChannel(Channel ch) throws Exception {
            }
        };
    }
}