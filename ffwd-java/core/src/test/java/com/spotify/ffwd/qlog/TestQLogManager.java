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
        final AsyncFramework async = TinyAsync.builder().build();
        final ExecutorService executor = Executors.newFixedThreadPool(1);

        final QLogManager log = new QLogManager(Paths.get("./qlogtest"), async, executor);

        log.start().get();

        final ByteBuffer buf = ByteBuffer.allocate(1024 * 10);

        for (int i = 0; i < 1024 * 10; i++)
            buf.put((byte) 0x77);

        buf.rewind();

        final long position = log.position();

        for (int i = 0; i < 1000 * 20; i++)
            log.write(buf.asReadOnlyBuffer());

        log.trim(position);

        log.stop().get();

        executor.shutdown();
    }
}