package com.spotify.ffwd.plugin.ffwd;

import io.netty.buffer.ByteBuf;
import io.netty.channel.ChannelHandlerContext;
import io.netty.handler.codec.ByteToMessageDecoder;

import java.util.List;

import com.spotify.ffwd.netty.FastForwardDecoder;

public class FastForwardByteDecoder extends ByteToMessageDecoder {
    @Override
    protected void decode(ChannelHandlerContext ctx, ByteBuf msg, List<Object> out) throws Exception {
        FastForwardDecoder.decode(ctx.alloc(), msg, out);
    }
}
