package com.spotify.ffwd.plugin.ffwd;

import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.socket.DatagramPacket;
import io.netty.handler.codec.MessageToMessageDecoder;

import java.util.List;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class FastForwardDatagramDecoder extends MessageToMessageDecoder<DatagramPacket> {
    final long VERSION = 0;
    final long MAX_FRAME_SIZE = 65536;

    @Override
    protected void decode(ChannelHandlerContext ctx, DatagramPacket msg, List<Object> out) throws Exception {
        log.info("datagram: {}", msg);
        FastForwardDecoder.decode(ctx.alloc(), msg.content(), out);
        if (msg.content().readableBytes() > 0) {
            throw new Exception("Did not digest entire frame, bytes left: " + msg.content().readableBytes());
        }
    }
}
