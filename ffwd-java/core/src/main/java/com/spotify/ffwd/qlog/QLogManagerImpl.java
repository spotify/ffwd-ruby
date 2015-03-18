package com.spotify.ffwd.qlog;

import java.io.DataInput;
import java.io.DataInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.nio.charset.Charset;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Callable;

import lombok.RequiredArgsConstructor;
import lombok.ToString;
import lombok.extern.slf4j.Slf4j;

import com.google.common.collect.Lists;
import com.google.inject.Inject;
import com.google.inject.name.Named;

import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;

@Slf4j
public class QLogManagerImpl implements QLogManager {
    private static final Charset UTF8 = Charset.forName("UTF-8");
    private static final int MINIMUM_MAX_LOG_SIZE = 10000;
    private static final int DEFAULT_MAX_LOG_SIZE = 100000000;
    private static final String QLOG_FORMAT = "%016x";
    private static final String INDEX = "index";

    // 'FFLG'
    private static final byte[] MAGIC = new byte[] { 0x46, 0x46, 0x4c, 0x47 };
    private static final int HEADER_BASE_SIZE = MAGIC.length + Long.BYTES;
    private static final int BUFFER_SIZE = 4096;
    private static final int CURRENT_VERSION = 0;

    private final Path path;
    private final AsyncFramework async;
    private final int maxLogSize;

    private final Object $lock = new Object();
    private volatile boolean setup = false;

    // buffer to the tail log.
    private List<Header> headers;
    private Map<String, Long> offsets;
    private long position;
    private ByteBuffer tail;

    @Inject
    public QLogManagerImpl(@Named("path") final Path path, final AsyncFramework async) {
        this(path, async, DEFAULT_MAX_LOG_SIZE);
    }

    public QLogManagerImpl(final Path path, final AsyncFramework async, int maxLogSize) {
        if (maxLogSize < MINIMUM_MAX_LOG_SIZE)
            throw new IllegalArgumentException("maxLogSize");

        this.path = path;
        this.async = async;
        this.maxLogSize = maxLogSize;
    }

    /**
     * Trim the head of the on-disk log (if necessary).
     *
     * @param position The position to trim to.
     */
    @Override
    public void trim(final long position) {
        if (!setup)
            throw new IllegalStateException("not setup");

        synchronized ($lock) {
            final Iterator<Header> iter = headers.iterator();

            final List<Header> unlink = Lists.newArrayList();

            Header current = iter.next();

            while (iter.hasNext()) {
                final Header next = iter.next();

                if (next.offset() >= position)
                    break;

                unlink.add(current);
                current = next;
            }

            for (final Header m : unlink) {
                headers.remove(m);

                log.info("Unlinking {}", m);

                try {
                    Files.delete(m.path());
                } catch (IOException e) {
                    log.error("Failed to unlink {}", m, e);
                }
            }
        }
    }

    @Override
    public void trim() {
        if (!setup)
            throw new IllegalStateException("not setup");

        synchronized ($lock) {
            trim(maxOffset());
        }
    }

    @Override
    public void update(String id, long position) {
        if (!setup)
            throw new IllegalStateException("not setup");

        synchronized ($lock) {
            offsets.put(id, position);
        }
    }

    /**
     * Return the current offset of the log.
     */
    @Override
    public long position() {
        if (!setup)
            throw new IllegalStateException("not setup");

        synchronized ($lock) {
            return position;
        }
    }

    /**
     * Write a buffer.
     *
     * It's limit will be used as the size of the buffer.
     *
     * @param input
     * @return
     * @throws IOException
     */
    @Override
    public long write(final ByteBuffer input) throws IOException {
        if (!setup)
            throw new IllegalStateException("not setup");

        synchronized ($lock) {
            writeEntry(position++, input.asReadOnlyBuffer());
            return position;
        }
    }

    @Override
    public AsyncFuture<Void> start() {
        if (setup)
            throw new IllegalStateException("already setup");

        if (!Files.isDirectory(path))
            throw new IllegalStateException("log path is not a directory: " + path);

        return async.call(new Callable<Void>() {
            @Override
            public Void call() throws Exception {
                synchronized ($lock) {
                    if (setup)
                        return null;

                    start0();
                    setup = true;
                }

                return null;
            }
        });
    }

    @Override
    public AsyncFuture<Void> stop() {
        if (!setup)
            throw new IllegalStateException("not setup");

        return async.call(new Callable<Void>() {
            @Override
            public Void call() throws Exception {
                synchronized ($lock) {
                    if (!setup)
                        return null;

                    stop0();
                    setup = false;
                }

                return null;
            }
        });
    }

    private long maxOffset() {
        long offset = position();

        for (final Map.Entry<String, Long> e : offsets.entrySet())
            offset = Math.min(offset, e.getValue());

        return offset;
    }

    private void writeEntry(final long position, final ByteBuffer input) throws IOException {
        final Header header = tail();

        if (header == null)
            throw new IllegalStateException("header");

        final Header writeTo;

        // expand the log with another on-disk entry.
        if (tail.position() + input.remaining() > tail.capacity()) {
            flush(header);
            tail.rewind();

            writeTo = appendHeader(position);

            if (tail.position() + input.remaining() > tail.capacity())
                throw new IOException("entry too large");
        } else {
            writeTo = header;
        }

        writeTo.writeEntry(tail, input);
    }

    private void stop0() throws IOException {
        final Header header = tail();

        if (header == null)
            throw new IllegalStateException("header");

        flushIndex();
        flush(header);
    }

    private Map<String, Long> readIndex() throws IOException {
        final Map<String, Long> offsets = new HashMap<>();

        final Path index = this.path.resolve(INDEX);

        if (!Files.isReadable(index))
            return offsets;

        final ByteBuffer reader = ByteBuffer.allocate(12);

        try (final InputStream input = Files.newInputStream(index)) {
            while (true) {
                reader.rewind();

                final int read = input.read(reader.array(), 0, 12);

                if (read < 12)
                    break;

                final int length = reader.getInt();
                final long offset = reader.getLong();
                final byte[] idBytes = new byte[length];
                input.read(idBytes);
                final String id = new String(idBytes, UTF8);
                offsets.put(id, offset);
            }
        }

        return offsets;
    }

    private void flushIndex() throws IOException {
        final Path index = this.path.resolve(INDEX);

        final ByteBuffer writer = ByteBuffer.allocate(12);

        try (final OutputStream output = Files.newOutputStream(index)) {
            for (final Map.Entry<String, Long> e : offsets.entrySet()) {
                writer.rewind();

                final byte[] idBytes = e.getKey().getBytes(UTF8);
                writer.putInt(idBytes.length);
                writer.putLong(e.getValue());
                writer.flip();
                output.write(writer.array(), 0, writer.remaining());
                output.write(idBytes);
            }
        }
    }

    private void flush(final Header header) throws IOException {
        final ByteBuffer source = tail.asReadOnlyBuffer();
        source.flip();

        log.info("Saving: {}", header.path());

        final byte[] buffer = new byte[BUFFER_SIZE];

        final ByteBuffer segment = ByteBuffer.allocate(12);

        // copy tail buffer into file.
        try (final OutputStream output = Files.newOutputStream(header.path())) {
            while (source.remaining() > 0) {
                int size = Math.min(BUFFER_SIZE, source.remaining());
                source.get(buffer, 0, size);
                output.write(buffer, 0, size);
            }
        }
    }

    private Header tail() {
        if (headers.isEmpty())
            return null;

        return headers.get(headers.size() - 1);
    }

    private void start0() throws IOException {
        final List<Header> headers = readAllHeaders();

        this.offsets = readIndex();

        // initializing
        if (headers.isEmpty()) {
            log.info("initializing {}", path);

            this.tail = ByteBuffer.allocate(maxLogSize);
            this.position = 0;
            this.headers = headers;

            appendHeader(0);
            return;
        }

        final Header header = headers.get(headers.size() - 1);

        final ByteBuffer tail = readPath(header.path());
        final ByteBuffer source = tail.asReadOnlyBuffer();

        source.flip();

        final long position = countEntries(header, source);

        tail.position(source.position());

        this.tail = tail;
        this.position = header.offset() + position;
        this.headers = headers;
    }

    private List<Header> readAllHeaders() throws IOException {
        final List<Header> headers = Lists.newLinkedList();

        try (final DirectoryStream<Path> files = Files.newDirectoryStream(path)) {
            for (final Path f : files) {
                final String name = f.getFileName().toString();
                final Path abs = f.toAbsolutePath();

                log.info("Loading metadata from: {}", abs);

                try (final InputStream input = Files.newInputStream(abs)) {
                    headers.add(readHeader(name, abs, input));
                } catch (Exception e) {
                    log.error("Failed to read log file: {}", abs, e);
                    continue;
                }
            }
        }

        Collections.sort(headers);
        return headers;
    }

    private long countEntries(final Header header, final ByteBuffer source) {
        long offset = 0;

        // skip header
        source.position(HEADER_BASE_SIZE + header.size());

        while (source.remaining() > 0) {
            // break on corrupt entry.
            if (header.read(source) == null)
                break;

            offset += 1;
        }

        return offset;
    }

    private ByteBuffer readPath(final Path path) throws IOException {
        final long logSize = Files.size(path);

        if (logSize > Integer.MAX_VALUE)
            throw new IllegalStateException("file too large: " + path);

        final int actual = Math.max((int) logSize, maxLogSize);

        if (actual > maxLogSize)
            log.warn("grew max to {} since tail file larger than maximum {}", actual, maxLogSize);

        final ByteBuffer buffer = ByteBuffer.allocate(actual);

        try (final InputStream input = Files.newInputStream(path)) {
            final byte[] local = new byte[4096];

            while (true) {
                final int read = input.read(local);

                if (read <= 0)
                    break;

                buffer.put(local, 0, read);
            }
        }

        return buffer;
    }

    private Header appendHeader(final long offset) throws IOException {
        final Path path = this.path.resolve(String.format(QLOG_FORMAT, offset)).toAbsolutePath();

        if (tail.position() != 0)
            throw new IllegalStateException("tail should be in position zero");

        final Header0 header0 = new Header0(path, offset);

        tail.put(MAGIC);
        tail.putInt(CURRENT_VERSION);
        header0.write(tail);

        headers.add(header0);

        return header0;
    }

    private Header readHeader(String name, Path path, InputStream source) throws IOException {
        try (final DataInputStream d = new DataInputStream(source)) {
            final byte[] magic = new byte[4];

            d.read(magic);

            if (!Arrays.equals(MAGIC, magic))
                throw new IllegalStateException("Magic bytes do not match");

            final int version = d.readInt();

            if (version == 0)
                return readHeader0(name, path, d);

            throw new IllegalStateException("Unsupported log version: " + version);
        }
    }

    private Header readHeader0(String name, Path path, DataInput source) throws IOException {
        final long offset = source.readLong();
        return new Header0(path, offset);
    }

    private static interface Header extends Comparable<Header> {
        public Path path();

        public long offset();

        public int size();

        public ByteBuffer read(ByteBuffer source);

        public void writeEntry(ByteBuffer buffer, ByteBuffer input);

        public void write(ByteBuffer target);
    }

    @RequiredArgsConstructor
    @ToString(of = { "path", "offset" })
    private static class Header0 implements Header {
        private final Path path;
        private final long offset;

        @Override
        public Path path() {
            return path;
        }

        @Override
        public long offset() {
            return offset;
        }

        @Override
        public int size() {
            return 4;
        }

        @Override
        public ByteBuffer read(ByteBuffer source) {
            final ByteBuffer slice = source.slice();

            // buffer to short.
            if (slice.remaining() < size())
                return null;

            // each entry prefixed with its length.
            final int size = slice.getInt();

            final ByteBuffer result = slice.slice();

            if (result.remaining() < size)
                return null;

            result.limit(size);

            // update source position
            source.position(source.position() + 4 + size);
            return result;
        }

        @Override
        public void writeEntry(final ByteBuffer buffer, final ByteBuffer input) {
            buffer.putInt(input.remaining());
            buffer.put(input);
        }

        @Override
        public void write(ByteBuffer target) {
            target.putLong(offset);
        }

        @Override
        public int compareTo(Header o) {
            return Long.compare(offset, o.offset());
        }
    }
}