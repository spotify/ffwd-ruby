package com.spotify.ffwd.model;

import java.util.Date;
import java.util.Map;
import java.util.Set;

import lombok.Data;
import lombok.EqualsAndHashCode;

@Data
@EqualsAndHashCode(of = { "key", "tags", "attributes" })
public class Event {
    private final String key;
    private final double value;
    private final Date time;
    private final long ttl;
    private final String state;
    private final String description;
    private final String host;
    private final Set<String> tags;
    private final Map<String, String> attributes;
}
