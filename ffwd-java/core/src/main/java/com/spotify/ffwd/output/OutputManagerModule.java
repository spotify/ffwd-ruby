package com.spotify.ffwd.output;

import java.util.List;
import java.util.Map;
import java.util.Set;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.google.common.base.Optional;
import com.google.common.base.Supplier;
import com.google.common.collect.Lists;
import com.google.inject.Key;
import com.google.inject.Module;
import com.google.inject.PrivateModule;
import com.google.inject.Provides;
import com.google.inject.Scopes;
import com.google.inject.Singleton;
import com.google.inject.multibindings.Multibinder;
import com.google.inject.name.Named;
import com.google.inject.name.Names;
import com.spotify.ffwd.AgentConfig;

public class OutputManagerModule {
    private final List<OutputPlugin> DEFAULT_PLUGINS = Lists.newArrayList();

    private final List<OutputPlugin> plugins;

    @JsonCreator
    public OutputManagerModule(@JsonProperty("plugins") List<OutputPlugin> plugins) {
        this.plugins = Optional.of(plugins).or(DEFAULT_PLUGINS);
    }

    public Module module() {
        return new PrivateModule() {
            @Provides
            @Singleton
            public List<PluginSink> sources(final Set<PluginSink> sinks) {
                return Lists.newArrayList(sinks);
            }

            @Provides
            @Singleton
            @Named("attributes")
            public Map<String, String> attributes(AgentConfig config) {
                return config.getAttributes();
            }

            @Provides
            @Singleton
            @Named("tags")
            public Set<String> tags(AgentConfig config) {
                return config.getTags();
            }

            @Provides
            @Singleton
            @Named("ttl")
            public long ttl(AgentConfig config) {
                return config.getTtl();
            }

            @Override
            protected void configure() {
                bind(OutputManager.class).to(OutputManagerImpl.class).in(Scopes.SINGLETON);
                expose(OutputManager.class);

                bindPlugins();
            }

            private void bindPlugins() {
                final Multibinder<PluginSink> sinks = Multibinder.newSetBinder(binder(), PluginSink.class);

                int i = 0;

                for (final OutputPlugin p : plugins) {
                    final Key<PluginSink> k = Key.get(PluginSink.class, Names.named(String.valueOf(i++)));
                    install(p.module(k));
                    sinks.addBinding().to(k);
                }
            }
        };
    }

    public static Supplier<OutputManagerModule> supplyDefault() {
        return new Supplier<OutputManagerModule>() {
            @Override
            public OutputManagerModule get() {
                return new OutputManagerModule(null);
            }
        };
    }
}
