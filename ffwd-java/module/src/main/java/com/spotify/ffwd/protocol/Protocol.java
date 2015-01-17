package com.spotify.ffwd.protocol;

import java.net.InetSocketAddress;

import lombok.Data;

@Data
public class Protocol {
    private final ProtocolType type;
    private final InetSocketAddress address;
}