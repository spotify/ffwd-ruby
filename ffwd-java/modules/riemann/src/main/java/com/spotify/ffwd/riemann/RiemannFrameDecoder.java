package com.spotify.ffwd.riemann;

import io.netty.buffer.ByteBuf;
import io.netty.channel.ChannelHandlerContext;
import io.netty.handler.codec.ByteToMessageDecoder;
import io.netty.handler.codec.CorruptedFrameException;

import java.util.List;

import com.google.inject.Inject;

/**
 * Parses and unpacks length-prefixed streams of Proto.Msg messages.
 */
public class RiemannFrameDecoder extends ByteToMessageDecoder {
    private static final int MAX_SIZE = 0xffffff;

    @Inject
    private RiemannSerialization serializer;

    @Override
    protected void decode(ChannelHandlerContext ctx, ByteBuf in, List<Object> out) throws Exception {
        if (in.readableBytes() < 8)
            return;

        final long length = in.getUnsignedInt(0);

        if (length > MAX_SIZE)
            throw new CorruptedFrameException(String.format("frame size (%s) larger than max (%d)", length, MAX_SIZE));

        final int intLength = (int) length;

        if (in.readableBytes() < (4 + length))
            return;

        in.skipBytes(4);
        final ByteBuf frame = in.readBytes(intLength);

        try {
            out.add(serializer.parse0(frame));
        } finally {
            frame.release();
        }
    }
}