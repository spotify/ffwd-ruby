package com.spotify.ffwd;

import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelInboundHandlerAdapter;
import io.netty.channel.ChannelInitializer;
import io.netty.channel.EventLoopGroup;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.socket.DatagramChannel;
import io.netty.util.HashedWheelTimer;
import io.netty.util.concurrent.DefaultEventExecutor;
import io.netty.util.concurrent.EventExecutor;
import lombok.extern.slf4j.Slf4j;

import com.spotify.ffwd.plugin.ffwd.FastForwardDatagramDecoder;
import com.spotify.ffwd.protocol.tcp.TCP;
import com.spotify.ffwd.protocol.udp.UDP;

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
		final UDP udp = new UDP(timer, workerGroup);

		udp.bind("localhost", 19091, new ChannelInitializer<DatagramChannel>() {
			@Override
			protected void initChannel(DatagramChannel ch) throws Exception {
				ch.pipeline().addLast(new FastForwardDatagramDecoder());
				ch.pipeline().addLast(new ChannelInboundHandlerAdapter() {
					@Override
					public void channelRead(ChannelHandlerContext ctx,
							Object msg) throws Exception {
						log.info("read: {}", msg);
					}

					@Override
					public void exceptionCaught(ChannelHandlerContext ctx,
							Throwable cause) throws Exception {
						log.error("Closing connection with error", cause);
						ctx.channel().close();
					}
				});
			}
		});
	}
}
