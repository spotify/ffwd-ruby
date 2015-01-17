package com.spotify.ffwd.protocol.tcp;

import io.netty.bootstrap.Bootstrap;
import io.netty.bootstrap.ServerBootstrap;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelInitializer;
import io.netty.channel.ChannelOption;
import io.netty.channel.EventLoopGroup;
import io.netty.channel.socket.SocketChannel;
import io.netty.channel.socket.nio.NioServerSocketChannel;
import io.netty.channel.socket.nio.NioSocketChannel;
import io.netty.util.Timer;

import java.util.concurrent.TimeUnit;

import lombok.AllArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import com.spotify.ffwd.protocol.Protocol;
import com.spotify.ffwd.protocol.retrier.ChannelRetrier;

@Slf4j
@AllArgsConstructor
public class TCP implements Protocol {
    private final Timer timer;
    private final EventLoopGroup bossGroup;
    private final EventLoopGroup workerGroup;

    public void bind(final String host, final int port, ChannelInitializer<SocketChannel> initializer) {
        final ServerBootstrap b = new ServerBootstrap();

        b.group(bossGroup, workerGroup);
        b.channel(NioServerSocketChannel.class);
        b.childHandler(initializer);

        b.option(ChannelOption.SO_BACKLOG, 128);
        b.childOption(ChannelOption.SO_KEEPALIVE, true);

        final ChannelRetrier.ChannelAction action = new ChannelRetrier.ChannelAction() {
            @Override
            public ChannelFuture run() {
                return b.bind(host, port);
            }

            @Override
            public void failed(int attempt, long delay, Throwable cause) {
                final long seconds = TimeUnit.SECONDS.convert(delay, TimeUnit.MILLISECONDS);
                log.info("Bind tcp://{}:{} (attempt #{}) failed, retrying in {}s. Caused by: {}", host, port, attempt,
                        seconds, cause);
            }

            @Override
            public void success() {
                log.info("Bound to tcp://{}:{}", host, port);
            }
        };

        ChannelRetrier.setupExponential(timer, action);
    }

    public void connect(final String host, final int port, ChannelInitializer<SocketChannel> initializer) {
        final Bootstrap b = new Bootstrap();

        b.group(workerGroup);
        b.channel(NioSocketChannel.class);
        b.handler(initializer);

        b.option(ChannelOption.SO_KEEPALIVE, true);

        final ChannelRetrier.ChannelAction action = new ChannelRetrier.ChannelAction() {
            @Override
            public ChannelFuture run() {
                return b.connect(host, port);
            }

            @Override
            public void failed(int attempt, long delay, Throwable cause) {
                final long seconds = TimeUnit.SECONDS.convert(delay, TimeUnit.MILLISECONDS);
                log.info("Connect tcp://{}:{} (attempt #{}) failed, reconnecting in {}s. Caused by: {}", host, port,
                        attempt, seconds, cause);
            }

            @Override
            public void success() {
                log.info("Connected to tcp://{}:{}", host, port);
            }
        };

        ChannelRetrier.setupExponential(timer, action);
    }
}
