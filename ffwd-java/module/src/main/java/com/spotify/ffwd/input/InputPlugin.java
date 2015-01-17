package com.spotify.ffwd.input;

import com.google.inject.Key;
import com.google.inject.Module;

public interface InputPlugin {
    public Module module(Key<PluginSource> key);
}
