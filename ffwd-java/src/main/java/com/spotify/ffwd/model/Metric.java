package com.spotify.ffwd.model;

import java.util.Date;
import java.util.List;
import java.util.Map;

import lombok.Data;

@Data
public class Metric {
	private final String key;
	private final double value;
	private final Date time;
	private final String host;
	private final List<String> tags;
	private final Map<String, String> attributes;
	private final String source;
	private final String proc;
}
