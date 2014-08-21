package com.spotify.ffwd.protocol.udp;

import io.netty.bootstrap.Bootstrap;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelInitializer;
import io.netty.channel.ChannelOption;
import io.netty.channel.EventLoopGroup;
import io.netty.channel.socket.DatagramChannel;
import io.netty.channel.socket.nio.NioDatagramChannel;
import io.netty.util.Timer;

import java.util.concurrent.TimeUnit;

import lombok.AllArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import com.spotify.ffwd.protocol.Protocol;
import com.spotify.ffwd.protocol.retrier.ChannelRetrier;

@Slf4j
@AllArgsConstructor
public class UDP implements Protocol {
	private final Timer timer;
	private final EventLoopGroup workerGroup;

	public void bind(final String host, final int port,
			ChannelInitializer<DatagramChannel> initializer) {
		final Bootstrap b = new Bootstrap();

		b.group(workerGroup);
		b.channel(NioDatagramChannel.class);
		b.handler(initializer);

		// b.option(ChannelOption.SO_RCVBUF, 128);

		final ChannelRetrier.ChannelAction action = new ChannelRetrier.ChannelAction() {
			@Override
			public ChannelFuture run() {
				return b.bind(host, port);
			}

			@Override
			public void failed(int attempt, long delay, Throwable cause) {
				final long seconds = TimeUnit.SECONDS.convert(delay,
						TimeUnit.MILLISECONDS);
				log.info(
						"Bind udp://{}:{} (attempt #{}) failed, retrying in {}s. Caused by: {}",
						host, port, attempt, seconds, cause);
			}

			@Override
			public void success() {
				log.info("Bound to udp://{}:{}", host, port);
			}
		};

		ChannelRetrier.setupExponential(timer, action);
	}

	public void connect(final String host, final int port,
			ChannelInitializer<DatagramChannel> initializer) {
		final Bootstrap b = new Bootstrap();

		b.group(workerGroup);
		b.channel(NioDatagramChannel.class);
		b.handler(initializer);

		b.option(ChannelOption.SO_KEEPALIVE, true);

		final ChannelRetrier.ChannelAction action = new ChannelRetrier.ChannelAction() {
			@Override
			public ChannelFuture run() {
				return b.connect();
			}

			@Override
			public void failed(int attempt, long delay, Throwable cause) {
				final long seconds = TimeUnit.SECONDS.convert(delay,
						TimeUnit.MILLISECONDS);
				log.info(
						"Connect udp://{}:{} (attempt #{}) failed, reconnecting in {}s. Caused by: {}",
						host, port, attempt, seconds, cause);
			}

			@Override
			public void success() {
				log.info("Connected to udp://{}:{}", host, port);
			}
		};

		ChannelRetrier.setupExponential(timer, action);
	}
}
