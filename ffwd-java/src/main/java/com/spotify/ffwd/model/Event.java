package com.spotify.ffwd.model;

import java.util.Date;
import java.util.List;
import java.util.Map;

import lombok.Data;

@Data
public class Event {
	private final String key;
	private final double value;
	private final Date time;
	private final Long ttl;
	private final String state;
	private final String description;
	private final String host;
	private final List<String> tags;
	private final Map<String, String> attributes;
}
