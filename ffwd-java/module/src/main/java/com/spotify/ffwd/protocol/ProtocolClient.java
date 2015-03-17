package com.spotify.ffwd.protocol;

import io.netty.channel.Channel;
import io.netty.channel.ChannelInitializer;

public interface ProtocolClient {
    public ChannelInitializer<Channel> initializer();
}