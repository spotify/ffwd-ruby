package com.spotify.ffwd.protocol;

import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelFutureListener;
import io.netty.util.Timeout;
import io.netty.util.Timer;
import io.netty.util.TimerTask;

import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

import com.google.inject.Inject;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;
import eu.toolchain.async.FutureFinished;
import eu.toolchain.async.ResolvableFuture;

public class ChannelUtils {
    private static final long TIMEOUT = 1000;

    /* ~15m */
    private static final long MAX_TIMEOUT = 1000 * 1024;

    @Inject
    private Timer timer;

    @Inject
    private AsyncFramework async;

    public interface ChannelAction {
        public ChannelFuture run();

        public void retry(int attempt, long delay, Throwable cause);

        public void success();
    }

    public AsyncFuture<ChannelFuture> retry(ChannelAction action) {
        final ResolvableFuture<ChannelFuture> handle = async.future();

        final AtomicReference<Timeout> currentTimeout = new AtomicReference<>();

        handle.on(new FutureFinished() {
            @Override
            public void finished() throws Exception {
                final Timeout t = currentTimeout.getAndSet(null);

                if (t != null)
                    t.cancel();
            }
        });

        tryAction(action, 0, handle, currentTimeout);
        return handle;
    }

    private void tryAction(final ChannelAction action, final int attempt, final ResolvableFuture<ChannelFuture> handle,
            final AtomicReference<Timeout> currentTimeout) {
        if (handle.isCancelled()) {
            currentTimeout.set(null);
            return;
        }

        final ChannelFuture actual = action.run();

        final long delay = Math.min(MAX_TIMEOUT, (long) (TIMEOUT * Math.pow(2, attempt)));

        final ChannelFutureListener listener = new ChannelFutureListener() {
            @Override
            public void operationComplete(ChannelFuture future) throws Exception {
                // action succeded
                if (future.isSuccess()) {
                    handle.resolve(future);
                    action.success();
                    return;
                }

                // action failed, so we need to retry eventually.
                final Timeout timeout = timer.newTimeout(new TimerTask() {
                    @Override
                    public void run(Timeout timeout) throws Exception {
                        tryAction(action, attempt + 1, handle, currentTimeout);
                    }
                }, delay, TimeUnit.MILLISECONDS);

                currentTimeout.set(timeout);

                // check if handle is done, in which case the timeout should be cancelled.
                if (handle.isDone()) {
                    currentTimeout.set(null);
                    timeout.cancel();
                    return;
                }

                action.retry(attempt, delay, future.cause());
            }
        };

        actual.addListener(listener);
    }
}
