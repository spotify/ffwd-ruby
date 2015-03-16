package com.spotify.ffwd.module;

import lombok.Data;

import com.fasterxml.jackson.databind.jsontype.NamedType;
import com.fasterxml.jackson.databind.module.SimpleModule;
import com.google.inject.Inject;
import com.google.inject.name.Named;
import com.spotify.ffwd.input.InputPlugin;
import com.spotify.ffwd.output.OutputPlugin;
import com.spotify.ffwd.serializer.Serializer;

@Data
public class PluginContextImpl implements PluginContext {
    @Inject
    @Named("application/yaml+config")
    private SimpleModule module;

    @Override
    public void registerInput(String name, Class<? extends InputPlugin> input) {
        module.registerSubtypes(new NamedType(input, name));
    }

    @Override
    public void registerOutput(String name, Class<? extends OutputPlugin> output) {
        module.registerSubtypes(new NamedType(output, name));
    }

    @Override
    public void registerSerializer(String name, Class<? extends Serializer> serializer) {
        module.registerSubtypes(new NamedType(serializer, name));
    }
}