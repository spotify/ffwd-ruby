package com.spotify.ffwd.protocol.retrier;

import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelFutureListener;
import io.netty.util.Timeout;
import io.netty.util.Timer;
import io.netty.util.TimerTask;

import java.util.concurrent.TimeUnit;

public class ChannelRetrier {
    private static final long TIMEOUT = 1000;

    /* ~15m */
    private static final long MAX_TIMEOUT = 1000 * 1024;

    public interface ChannelAction {
        public ChannelFuture run();

        public void failed(int attempt, long delay, Throwable cause);

        public void success();
    }

    public static void setupExponential(Timer timer, ChannelAction action) {
        tryAction(timer, action, 0);
    }

    private static void tryAction(final Timer timer, final ChannelAction action, final int attempt) {
        final ChannelFuture actual = action.run();

        actual.addListener(new ChannelFutureListener() {
            @Override
            public void operationComplete(ChannelFuture future) throws Exception {
                if (future.isCancelled()) {
                    return;
                }

                if (!future.isSuccess()) {
                    final long delay = Math.min(MAX_TIMEOUT, (long) (TIMEOUT * Math.pow(2, attempt)));

                    timer.newTimeout(new TimerTask() {
                        @Override
                        public void run(Timeout timeout) throws Exception {
                            tryAction(timer, action, attempt + 1);
                        }
                    }, delay, TimeUnit.MILLISECONDS);

                    action.failed(attempt, delay, future.cause());
                    return;
                }

                final ChannelFutureListener onClose = new ChannelFutureListener() {
                    @Override
                    public void operationComplete(ChannelFuture future) throws Exception {
                        tryAction(timer, action, 0);
                    }
                };

                future.channel().closeFuture().addListener(onClose);
                action.success();
            }
        });
    }
}
