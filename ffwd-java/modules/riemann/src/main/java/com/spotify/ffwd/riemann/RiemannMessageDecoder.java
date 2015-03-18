package com.spotify.ffwd.riemann;

import io.netty.channel.ChannelHandler.Sharable;
import io.netty.channel.ChannelHandlerContext;
import io.netty.handler.codec.MessageToMessageDecoder;

import java.util.List;

import com.aphyr.riemann.Proto;
import com.google.inject.Inject;

@Sharable
public class RiemannMessageDecoder extends MessageToMessageDecoder<Proto.Msg> {
    @Inject
    private RiemannSerialization serializer;

    @Override
    protected void decode(ChannelHandlerContext ctx, Proto.Msg msg, List<Object> out) throws Exception {
        final List<Object> messages = serializer.decode0(msg);

        if (messages == null)
            return;

        for (final Object frame : messages)
            out.add(frame);
    }
}