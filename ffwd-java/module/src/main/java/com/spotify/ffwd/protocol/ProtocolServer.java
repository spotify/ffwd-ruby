package com.spotify.ffwd.protocol;

import io.netty.channel.Channel;
import io.netty.channel.ChannelInitializer;

public interface ProtocolServer {
    public ChannelInitializer<Channel> initializer();
}