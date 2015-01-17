package com.spotify.ffwd.protobuf;

import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelInboundHandlerAdapter;
import io.netty.channel.ChannelInitializer;
import io.netty.channel.socket.SocketChannel;

import com.google.inject.Inject;
import com.spotify.ffwd.input.InputManager;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;
import com.spotify.ffwd.netty.FastForwardDatagramDecoder;
import com.spotify.ffwd.protocol.ProtocolServer;

public class ProtobufUDPProtocolServer implements ProtocolServer {
    @Inject
    private InputManager input;

    @Override
    public final ChannelInitializer<SocketChannel> initializer() {
        return new ChannelInitializer<SocketChannel>() {
            @Override
            protected void initChannel(SocketChannel ch) throws Exception {
                ch.pipeline().addLast(new FastForwardDatagramDecoder());
                ch.pipeline().addLast(new ChannelInboundHandlerAdapter() {
                    @Override
                    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
                        if (msg instanceof Event) {
                            input.receiveEvent((Event)msg);
                            return;
                        }

                        if (msg instanceof Metric) {
                            input.receiveMetric((Metric)msg);
                            return;
                        }
                    }

                    @Override
                    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
                        ctx.channel().close();
                    }
                });
            }
        };
    }
}
