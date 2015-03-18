package com.spotify.ffwd.riemann;

import io.netty.buffer.ByteBuf;
import io.netty.buffer.ByteBufOutputStream;
import io.netty.buffer.Unpooled;
import io.netty.channel.ChannelHandler.Sharable;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelInboundHandlerAdapter;

import java.io.IOException;

import com.aphyr.riemann.Proto;

@Sharable
public class RiemannResponder extends ChannelInboundHandlerAdapter {
    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
        ctx.channel().writeAndFlush(ack(true));
        ctx.fireChannelRead(msg);
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        ctx.channel().writeAndFlush(ack(false));
    }

    private ByteBuf ack(boolean ok) throws IOException {
        final Proto.Msg m = Proto.Msg.newBuilder().setOk(ok).build();

        final ByteBuf b = Unpooled.buffer();

        try (final ByteBufOutputStream output = new ByteBufOutputStream(b)) {
            m.writeTo(output);

            final ByteBuf frame = output.buffer();
            final ByteBuf buffer = Unpooled.buffer(4 + frame.readableBytes());

            buffer.writeInt(frame.readableBytes());
            buffer.writeBytes(frame);

            return buffer;
        } finally {
            b.release();
        }
    }
}