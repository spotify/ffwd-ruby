package com.spotify.ffwd.output;

import com.google.inject.Key;
import com.google.inject.Module;

public interface OutputPlugin {
    public Module module(Key<PluginSink> key);
}
