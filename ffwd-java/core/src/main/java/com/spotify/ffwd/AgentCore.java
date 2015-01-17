package com.spotify.ffwd;

import io.netty.channel.EventLoopGroup;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.util.HashedWheelTimer;
import io.netty.util.Timer;

import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Constructor;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutionException;

import lombok.extern.slf4j.Slf4j;

import com.fasterxml.jackson.core.JsonParseException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.module.SimpleModule;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import com.google.common.collect.Lists;
import com.google.inject.AbstractModule;
import com.google.inject.Guice;
import com.google.inject.Injector;
import com.google.inject.Key;
import com.google.inject.Module;
import com.google.inject.Provides;
import com.google.inject.Scopes;
import com.google.inject.Singleton;
import com.google.inject.name.Named;
import com.google.inject.name.Names;
import com.spotify.ffwd.input.InputManager;
import com.spotify.ffwd.input.InputPlugin;
import com.spotify.ffwd.module.FastForwardModule;
import com.spotify.ffwd.module.FasterXmlSubTypeMixIn;
import com.spotify.ffwd.module.PluginContext;
import com.spotify.ffwd.module.PluginContextImpl;
import com.spotify.ffwd.output.OutputManager;
import com.spotify.ffwd.output.OutputPlugin;
import com.spotify.ffwd.protocol.ChannelUtils;
import com.spotify.ffwd.protocol.ProtocolClients;
import com.spotify.ffwd.protocol.ProtocolClientsImpl;
import com.spotify.ffwd.protocol.ProtocolServers;
import com.spotify.ffwd.protocol.ProtocolServersImpl;

import eu.toolchain.async.AsyncCaller;
import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.AsyncFuture;
import eu.toolchain.async.TinyAsync;
import eu.toolchain.async.caller.DirectAsyncCaller;

@Slf4j
public class AgentCore {
    private final List<Class<? extends FastForwardModule>> modules;
    private final Path config;

    private AgentCore(final List<Class<? extends FastForwardModule>> modules, Path config) {
        this.modules = modules;
        this.config = config;
    }

    public void run() throws Exception {
        final Injector early = setupEarlyInjector();
        final AgentConfig config = readConfig(early);
        final Injector primary = setupPrimaryInjector(early, config);

        start(primary);
        log.info("Started");

        System.in.read();

        stop(primary);
        log.info("Stopped");
    }

    private void start(final Injector primary) throws Exception, InterruptedException, ExecutionException {
        final InputManager input = primary.getInstance(InputManager.class);
        final OutputManager output = primary.getInstance(OutputManager.class);

        final AsyncFramework async = primary.getInstance(AsyncFramework.class);
        final ArrayList<AsyncFuture<Void>> startup = Lists.newArrayList();

        startup.add(input.start());
        startup.add(output.start());

        log.info("Starting FastForward");
        async.collect(startup).get();
    }

    private void stop(final Injector primary) throws Exception, InterruptedException, ExecutionException {
        final InputManager input = primary.getInstance(InputManager.class);
        final OutputManager output = primary.getInstance(OutputManager.class);

        final AsyncFramework async = primary.getInstance(AsyncFramework.class);
        final ArrayList<AsyncFuture<Void>> startup = Lists.newArrayList();

        startup.add(input.stop());
        startup.add(output.stop());

        log.info("Stopping FastForward");
        async.collect(startup).get();
    }

    /**
     * Setup early application Injector.
     *
     * The early injector is used by modules to configure the system.
     * @throws Exception If something could not be set up.
     */
    private Injector setupEarlyInjector() throws Exception {
        final List<Module> modules = Lists.newArrayList();

        modules.add(new AbstractModule() {
            @Singleton
            @Provides
            @Named("application/yaml+config")
            public SimpleModule configModule() {
                final SimpleModule module = new SimpleModule();

                // Make InputPlugin, and OutputPlugin sub-type aware through the 'type' attribute.
                module.setMixInAnnotation(InputPlugin.class, FasterXmlSubTypeMixIn.class);
                module.setMixInAnnotation(OutputPlugin.class, FasterXmlSubTypeMixIn.class);

                return module;
            }

            @Override
            protected void configure() {
                bind(PluginContext.class).to(PluginContextImpl.class).in(Scopes.SINGLETON);
            }
        });

        final Injector injector = Guice.createInjector(modules);

        for (final FastForwardModule m : loadModules(injector)) {
            log.info("Setting up {}", m);

            try {
                m.setup();
            } catch(Exception e) {
                throw new Exception("Failed to call #setup() for module: " + m, e);
            }
        }

        return injector;
    }

    private AgentConfig readConfig(Injector early) throws IOException {
        final ObjectMapper mapper = new ObjectMapper(new YAMLFactory());
        final SimpleModule module = early.getInstance(Key.get(SimpleModule.class, Names.named("application/yaml+config")));

        mapper.registerModule(module);

        try (final InputStream input = Files.newInputStream(this.config)) {
            return mapper.readValue(input, AgentConfig.class);
        } catch(JsonParseException e) {
            throw new IOException("Failed to parse configuration", e);
        }
    }

    private List<FastForwardModule> loadModules(Injector injector) throws Exception {
        final List<FastForwardModule> modules = Lists.newArrayList();

        for (final Class<? extends FastForwardModule> module : this.modules) {
            final Constructor<? extends FastForwardModule> constructor;

            try {
                constructor = module.getConstructor();
            } catch (NoSuchMethodException e) {
                throw new Exception("Expected empty constructor for class: " + module, e);
            }

            final FastForwardModule m;

            try {
                m = constructor.newInstance();
            } catch (ReflectiveOperationException e) {
                throw new Exception("Failed to call constructor for class: " + module, e);
            }

            injector.injectMembers(m);

            modules.add(m);
        }

        return modules;
    }

    /**
     * Setup primary Injector.
     *
     * @return The primary injector.
     */
    public Injector setupPrimaryInjector(final Injector early, final AgentConfig config) {
        final List<Module> modules = Lists.newArrayList();

        modules.add(new AbstractModule() {
            @Singleton
            @Provides
            private AsyncFramework async() {
                final AsyncCaller caller = new DirectAsyncCaller() {
                    @Override
                    protected void internalError(String what, Throwable e) {
                        log.error("Async call '{}' failed", what, e);
                    }
                };

                return TinyAsync.builder().caller(caller).build();
            }

            @Singleton
            @Provides
            @Named("workers")
            public EventLoopGroup workers() {
                return new NioEventLoopGroup();
            }

            @Override
            protected void configure() {
                bind(Timer.class).to(HashedWheelTimer.class).in(Scopes.SINGLETON);
                bind(ChannelUtils.class).in(Scopes.SINGLETON);
                bind(ProtocolServers.class).to(ProtocolServersImpl.class).in(Scopes.SINGLETON);
                bind(ProtocolClients.class).to(ProtocolClientsImpl.class).in(Scopes.SINGLETON);
            }
        });

        modules.add(config.getInput().module());
        modules.add(config.getOutput().module());

        return early.createChildInjector(modules);
    }

    public static Builder builder() {
        return new Builder();
    }

    public static final class Builder {
        private List<Class<? extends FastForwardModule>> modules = Lists.newArrayList();
        private Path config = Paths.get("ffwd.yaml");

        public Builder modules(List<Class<? extends FastForwardModule>> modules) {
            if (modules == null)
                throw new IllegalArgumentException("'modules' must not be null");

            this.modules = modules;
            return this;
        }

        public AgentCore build() {
            return new AgentCore(modules, config);
        }
    }
}
