package com.spotify.ffwd.protocol;

import io.netty.channel.ChannelFuture;

public interface ProtocolChannelSetup {
    ChannelFuture setup();
}
