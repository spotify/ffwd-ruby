package com.spotify.ffwd.json;

import io.netty.channel.ChannelInitializer;
import io.netty.channel.socket.SocketChannel;

import com.spotify.ffwd.protocol.ProtocolServer;

public class JsonUDPProtocolServer implements ProtocolServer {
    @Override
    public final ChannelInitializer<SocketChannel> initializer() {
        return new ChannelInitializer<SocketChannel>() {
            @Override
            protected void initChannel(SocketChannel ch) throws Exception {
                // TODO Auto-generated method stub
            }
        };
    }
}
