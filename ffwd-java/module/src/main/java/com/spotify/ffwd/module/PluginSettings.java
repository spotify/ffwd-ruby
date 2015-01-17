package com.spotify.ffwd.module;

public interface PluginSettings {
    public String get(String key, String defaultValue);

    public int getInt(String key, int defaultValue);
}