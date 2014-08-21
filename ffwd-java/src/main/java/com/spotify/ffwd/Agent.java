package com.spotify.ffwd;

import io.netty.channel.ChannelInitializer;
import io.netty.channel.EventLoopGroup;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.socket.SocketChannel;
import io.netty.util.HashedWheelTimer;
import io.netty.util.concurrent.DefaultEventExecutor;
import io.netty.util.concurrent.EventExecutor;
import lombok.extern.slf4j.Slf4j;

import com.spotify.ffwd.protocol.tcp.TCP;

@Slf4j
public class Agent {
	public static void main(String[] args) throws Exception {
		final EventExecutor executor = new DefaultEventExecutor();
		final HashedWheelTimer timer = new HashedWheelTimer();
		final EventLoopGroup bossGroup = new NioEventLoopGroup();
		final EventLoopGroup workerGroup = new NioEventLoopGroup();

		System.out.println("hello world!");
		log.info("Listening on 19091");
		final TCP tcp = new TCP(timer, bossGroup, workerGroup);

		tcp.connect("localhost", 19091,
				new ChannelInitializer<SocketChannel>() {
					@Override
					protected void initChannel(SocketChannel ch)
							throws Exception {
					}
				});

		tcp.bind("localhost", 19091, new ChannelInitializer<SocketChannel>() {
			@Override
			protected void initChannel(SocketChannel ch) throws Exception {
			}
		});
	}
}
