package com.spotify.ffwd.protocol.tcp;

import io.netty.bootstrap.ServerBootstrap;
import io.netty.channel.ChannelFuture;
import lombok.Data;

import com.spotify.ffwd.protocol.BindHandler;

@Data
public class TCPBindHandler implements BindHandler {
	private final ServerBootstrap bootstrap;
	private final String host;
	private final int port;

	@Override
	public ChannelFuture bind() {
		return bootstrap.bind(host, port);
	}
}
