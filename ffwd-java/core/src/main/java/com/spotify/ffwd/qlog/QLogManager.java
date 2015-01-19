package com.spotify.ffwd.qlog;

import java.io.DataInput;
import java.io.DataInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Iterator;
import java.util.List;
import java.util.concurrent.ExecutorService;

import lombok.Data;
import lombok.extern.slf4j.Slf4j;

import com.google.common.collect.Lists;
import com.google.inject.Inject;
import com.google.inject.name.Named;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;
import eu.toolchain.async.ResolvableFuture;

@Slf4j
public class QLogManager {
    private static final int BUFFER_SIZE = 4096;
    // 'FFLG'
    private static final byte[] MAGIC = new byte[] { 0x46, 0x46, 0x4c, 0x47 };
    private static final int CURRENT_VERSION = 0;

    // 100MB
    private static final int MAX_LOG_SIZE = 100000000;
    private static final String QLOG_FORMAT = "%016x";

    private final Path path;
    private final AsyncFramework async;
    private final ExecutorService executor;

    @Inject
    public QLogManager(@Named("path") final Path path, final AsyncFramework async, final ExecutorService executor) {
        this.path = path;
        this.async = async;
        this.executor = executor;
    }

    private List<EntryMetadata> entries = new ArrayList<>();

    private long tailPosition;

    // buffer to the tail log.
    private final ByteBuffer tailBuffer = ByteBuffer.allocate(MAX_LOG_SIZE);

    private final Object $lock = new Object();

    /**
     * Return the current offset of the log.
     */
    public long position() {
        synchronized ($lock) {
            return tailPosition;
        }
    }

    /**
     * Trim the head of the on-disk log (if necessary).
     *
     * @param position The position to trim to.
     */
    public void trim(long position) {
        synchronized ($lock) {
            final Iterator<EntryMetadata> iter = entries.listIterator();

            final List<EntryMetadata> unlink = Lists.newArrayList();

            EntryMetadata current = iter.next();

            while (iter.hasNext()) {
                final EntryMetadata next = iter.next();

                if (current.getBasePosition() < position && position < next.getBasePosition())
                    break;

                unlink.add(current);
                current = next;
            }

            for (final EntryMetadata m : unlink) {
                entries.remove(m);

                log.info("Unlinking {}", m);

                try {
                    Files.delete(m.getPath());
                } catch (IOException e) {
                    log.error("Failed to unlink {}", m, e);
                }
            }
        }
    }

    /**
     * Write a buffer.
     *
     * It's limit will be used as the size of the buffer.
     *
     * @param buffer
     * @return
     * @throws IOException
     */
    public long write(ByteBuffer buffer) throws IOException {
        synchronized ($lock) {
            writeEntry(tailPosition, buffer.asReadOnlyBuffer());
            tailPosition += 1;
            return tailPosition;
        }
    }

    private void writeEntry(long position, ByteBuffer buffer) throws IOException {
        // expand the log with another on-disk entry.
        if (tailBuffer.position() + buffer.remaining() > tailBuffer.capacity()) {
            saveTail();
            tailBuffer.rewind();

            appendEntryMetadata(position);

            if (tailBuffer.position() + buffer.remaining() > tailBuffer.capacity())
                throw new IOException("entry too large");
        }

        tailBuffer.putInt(buffer.remaining());
        tailBuffer.put(buffer);
    }

    public AsyncFuture<Void> start() {
        if (!Files.isDirectory(path))
            throw new IllegalStateException("log path is not a directory: " + path);

        final ResolvableFuture<Void> future = async.future();

        executor.submit(new Runnable() {
            @Override
            public void run() {
                try {
                    start0();
                } catch (Exception e) {
                    future.fail(e);
                    return;
                }

                future.resolve(null);
            }
        });

        return future;
    }

    public AsyncFuture<Void> stop() {
        final ResolvableFuture<Void> future = async.future();

        executor.submit(new Runnable() {
            @Override
            public void run() {
                try {
                    stop0();
                } catch (Exception e) {
                    future.fail(e);
                    return;
                }

                future.resolve(null);
            }
        });

        return future;
    }

    private void stop0() throws IOException {
        synchronized ($lock) {
            saveTail();
        }
    }

    private void saveTail() throws IOException {
        if (this.entries.isEmpty())
            throw new IllegalStateException("entries are empty, was QLogManager started?");

        final EntryMetadata tailEntry = tailEntry();

        final ByteBuffer source = tailBuffer.asReadOnlyBuffer();
        source.flip();

        log.info("Saving: {}", tailEntry);

        final byte[] buffer = new byte[BUFFER_SIZE];

        // copy tail buffer into file.
        try (final OutputStream output = Files.newOutputStream(tailEntry.getPath())) {
            while (source.remaining() > 0) {
                int size = Math.min(BUFFER_SIZE, source.remaining());
                source.get(buffer, 0, size);
                output.write(buffer, 0, size);
            }
        }
    }

    private EntryMetadata tailEntry() {
        if (entries.isEmpty())
            return null;

        return entries.get(entries.size() - 1);
    }

    private void start0() throws IOException {
        synchronized ($lock) {
            this.entries = loadEntries();
            loadTail();
        }
    }

    /**
     * Loads the currently known tail into memory.
     *
     * @throws IOException
     */
    private void loadTail() throws IOException {
        final EntryMetadata entry = tailEntry();

        // initial
        if (entry == null) {
            appendEntryMetadata(0);
            tailPosition = 0;
            return;
        }

        try (final InputStream input = Files.newInputStream(entry.getPath())) {
            readIntoTailBuffer(input);
        }

        updateTailPositionAndBuffer();
    }

    private void updateTailPositionAndBuffer() {
        final EntryMetadata entry = tailEntry();

        if (entry == null)
            throw new IllegalStateException("No tail entry");

        final ByteBuffer source = tailBuffer.asReadOnlyBuffer();

        source.flip();
        source.position(entry.getHeaderSize());

        long position = 0;

        while (source.remaining() > 0) {
            // break on corrupt entry.
            if (entry.readEntry(source) == null)
                break;

            position += 1;
        }

        tailPosition = entry.getBasePosition() + position;
        tailBuffer.position(source.position());
    }

    /**
     * Read the entirety of the given input stream into the tail buffer.
     *
     * @param input
     * @throws IOException
     */
    private void readIntoTailBuffer(final InputStream input) throws IOException {
        final byte[] buffer = new byte[4096];

        tailBuffer.rewind();

        while (true) {
            final int read = input.read(buffer);

            if (read <= 0)
                break;

            tailBuffer.put(buffer, 0, read);
        }
    }

    private void appendEntryMetadata(final long position) throws IOException {
        final Path abs = path.resolve(String.format(QLOG_FORMAT, position)).toAbsolutePath();

        if (tailBuffer.position() != 0)
            throw new IllegalStateException("tail should be in position zero");

        tailBuffer.put(MAGIC);
        tailBuffer.putInt(CURRENT_VERSION);
        tailBuffer.putLong(position);

        entries.add(new EntryMetadata0(CURRENT_VERSION, abs, position));
    }

    private List<EntryMetadata> loadEntries() throws IOException {
        final List<EntryMetadata> entries = Lists.newLinkedList();

        try (final DirectoryStream<Path> files = Files.newDirectoryStream(path)) {
            for (final Path f : files) {
                final String name = f.getFileName().toString();
                final Path abs = f.toAbsolutePath();

                log.info("Loading metadata from: {}", abs);

                try (final InputStream input = Files.newInputStream(abs)) {
                    entries.add(readEntry(name, abs, input));
                } catch (Exception e) {
                    log.error("Failed to read log file: {}", abs, e);
                    continue;
                }
            }
        }

        Collections.sort(entries);
        return entries;
    }

    private EntryMetadata readEntry(String name, Path path, InputStream source) throws IOException {
        try (final DataInputStream d = new DataInputStream(source)) {
            final byte[] magic = new byte[4];

            d.read(magic);

            if (!Arrays.equals(MAGIC, magic))
                throw new IllegalStateException("Magic bytes do not match");

            final int version = d.readInt();

            if (version == 0)
                return readEntryMetadata0(name, path, d);

            throw new IllegalStateException("Unsupported log version: " + version);
        }
    }

    private EntryMetadata readEntryMetadata0(String name, Path path, DataInput source) throws IOException {
        final long offset = source.readLong();
        return new EntryMetadata0(0, path, offset);
    }

    private static interface EntryMetadata extends Comparable<EntryMetadata> {
        public Path getPath();

        public long getBasePosition();

        public int getHeaderSize();

        public ByteBuffer readEntry(ByteBuffer source);
    }

    @Data
    private static class EntryMetadata0 implements EntryMetadata {
        private static final int HEADER_SIZE = 16;

        private final int version;
        private final Path path;
        private final long basePosition;

        @Override
        public int getHeaderSize() {
            return HEADER_SIZE;
        }

        @Override
        public int compareTo(EntryMetadata o) {
            return Long.compare(basePosition, o.getBasePosition());
        }

        @Override
        public ByteBuffer readEntry(ByteBuffer source) {
            final ByteBuffer slice = source.slice();

            if (slice.remaining() < 4)
                return null;

            final int size = slice.getInt();
            final ByteBuffer result = slice.slice();

            if (result.remaining() < size)
                return null;

            result.limit(size);
            source.position(source.position() + 4 + size);
            return result;
        }
    }
}