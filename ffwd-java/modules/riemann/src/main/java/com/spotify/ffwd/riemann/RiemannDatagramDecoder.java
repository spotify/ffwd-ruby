package com.spotify.ffwd.riemann;

import io.netty.channel.ChannelHandler.Sharable;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.socket.DatagramPacket;
import io.netty.handler.codec.MessageToMessageDecoder;

import java.util.List;

import com.google.inject.Inject;

@Sharable
public class RiemannDatagramDecoder extends MessageToMessageDecoder<DatagramPacket> {
    @Inject
    private RiemannSerialization serializer;

    @Override
    protected void decode(ChannelHandlerContext ctx, DatagramPacket packet, List<Object> out) throws Exception {
        out.add(serializer.parse0(packet.content()));
    }
}