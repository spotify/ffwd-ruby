package com.spotify.ffwd.module;

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
