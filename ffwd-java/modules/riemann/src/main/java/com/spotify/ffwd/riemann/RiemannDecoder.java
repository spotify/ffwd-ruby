package com.spotify.ffwd.riemann;

import io.netty.channel.ChannelHandler.Sharable;
import io.netty.channel.ChannelHandlerContext;
import io.netty.handler.codec.CorruptedFrameException;
import io.netty.handler.codec.MessageToMessageDecoder;

import java.util.List;

import com.google.inject.Inject;

@Sharable
public class RiemannDecoder extends MessageToMessageDecoder<RiemannFrame> {
    @Inject
    private RiemannSerializer serializer;

    @Override
    protected void decode(ChannelHandlerContext ctx, RiemannFrame in, List<Object> out) throws Exception {
        decodeOne(ctx, in, out);
    }

    private void decodeOne(ChannelHandlerContext ctx, RiemannFrame in, List<Object> out) throws Exception {
        final List<Object> frames;

        try {
            switch (in.getVersion()) {
            case 0:
                frames = serializer.decode0(in.getBuffer());
                break;
            default:
                throw new CorruptedFrameException("invalid version: " + in.getVersion());
            }
        } finally {
            in.getBuffer().release();
        }

        if (frames != null) {
            for (final Object frame : frames)
                out.add(frame);
        }
    }
}
