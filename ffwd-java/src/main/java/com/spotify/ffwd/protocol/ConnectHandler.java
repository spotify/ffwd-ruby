package com.spotify.ffwd.protocol;

import io.netty.channel.ChannelFuture;

public interface ConnectHandler {
	public ChannelFuture connect();
}
