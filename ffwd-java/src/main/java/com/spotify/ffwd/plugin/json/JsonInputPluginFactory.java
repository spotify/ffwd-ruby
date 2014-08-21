package com.spotify.ffwd.plugin.json;

import lombok.Data;

import com.spotify.ffwd.plugin.InputPlugin;
import com.spotify.ffwd.plugin.InputPluginFactory;
import com.spotify.ffwd.protocol.Protocol;

@Data
public class JsonInputPluginFactory implements InputPluginFactory {
	private final Protocol protocol;

	@Override
	public InputPlugin build() {
		return new JsonInputPlugin();
	}
}
