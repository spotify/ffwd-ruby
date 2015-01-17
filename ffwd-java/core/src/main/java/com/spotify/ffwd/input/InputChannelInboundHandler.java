package com.spotify.ffwd.input;

import io.netty.channel.ChannelHandler.Sharable;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelInboundHandlerAdapter;
import lombok.extern.slf4j.Slf4j;

import com.google.inject.Inject;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;

@Slf4j
@Sharable
public class InputChannelInboundHandler extends ChannelInboundHandlerAdapter {
    @Inject
    private InputManager input;

    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
        if (msg instanceof Event) {
            input.receiveEvent((Event) msg);
            return;
        }

        if (msg instanceof Metric) {
            input.receiveMetric((Metric) msg);
            return;
        }

        log.error("{}: Got garbage '{}' in channel, closing", ctx.channel(), msg);
        ctx.channel().close();
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        log.info("{}: Error in channel, closing", ctx.channel(), cause);
        ctx.channel().close();
    }
}