package com.spotify.ffwd.qlog;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.file.Paths;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import org.junit.Test;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.TinyAsync;

public class TestQLogManager {
    @Test
    public void testBasic() throws InterruptedException, ExecutionException, IOException {
        final ExecutorService executor = Executors.newFixedThreadPool(1);
        final AsyncFramework async = TinyAsync.builder().executor(executor).build();

        final QLogManager log = new QLogManagerImpl(Paths.get("./qlogtest"), async, 1024 * 10);

        log.start().get();

        final ByteBuffer buf = ByteBuffer.allocate(1024);

        while (buf.remaining() > 0)
            buf.put((byte) 0x77);

        buf.flip();

        final long position = log.position();

        log.update("foo", position - 500);

        for (int i = 0; i < 1000; i++)
            log.write(buf.asReadOnlyBuffer());

        log.trim();

        log.stop().get();

        executor.shutdown();
    }
}