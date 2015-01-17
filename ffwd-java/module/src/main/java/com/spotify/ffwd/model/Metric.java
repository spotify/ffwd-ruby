package com.spotify.ffwd.model;

import java.util.Date;
import java.util.Map;
import java.util.Set;

import lombok.Data;

@Data
public class Metric {
    private final String key;
    private final double value;
    private final Date time;
    private final String host;
    private final Set<String> tags;
    private final Map<String, String> attributes;
    private final String proc;
}
