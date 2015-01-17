package com.spotify.ffwd.module;

import com.spotify.ffwd.input.InputPlugin;
import com.spotify.ffwd.output.OutputPlugin;

public interface PluginContext {
    /**
     * Register an input plugin.
     *
     * @param input
     */
    public void registerInput(String name, Class<? extends InputPlugin> input);

    /**
     * Register an output plugin.
     *
     * @param output
     */
    public void registerOutput(String name, Class<? extends OutputPlugin> output);
}