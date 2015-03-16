package com.spotify.ffwd.module;

import com.spotify.ffwd.input.InputPlugin;
import com.spotify.ffwd.output.OutputPlugin;
import com.spotify.ffwd.serializer.Serializer;

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

    /**
     * Register a serializer implementation.
     */
    public void registerSerializer(String name, Class<? extends Serializer> serializer);
}