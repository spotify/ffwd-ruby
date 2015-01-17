package com.spotify.ffwd.protocol;

import io.netty.channel.ChannelInitializer;
import io.netty.channel.socket.SocketChannel;

public interface ProtocolServer {
    public ChannelInitializer<SocketChannel> initializer();
}