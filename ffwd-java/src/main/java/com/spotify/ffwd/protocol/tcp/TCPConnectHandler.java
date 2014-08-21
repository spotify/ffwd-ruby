package com.spotify.ffwd.protocol.tcp;

import io.netty.bootstrap.Bootstrap;
import io.netty.channel.ChannelFuture;
import lombok.Data;

import com.spotify.ffwd.protocol.ConnectHandler;

@Data
public class TCPConnectHandler implements ConnectHandler {
	private final Bootstrap bootstrap;
	private final String host;
	private final int port;

	@Override
	public ChannelFuture connect() {
		return bootstrap.connect(host, port);
	}
}
