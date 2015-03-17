package com.spotify.ffwd.riemann;

import io.netty.buffer.ByteBuf;
import lombok.Data;

@Data
public class RiemannFrame {
    private final int version;
    private final ByteBuf buffer;
}