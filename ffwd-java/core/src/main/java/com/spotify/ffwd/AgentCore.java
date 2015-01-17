package com.spotify.ffwd;

import java.lang.reflect.Constructor;
import java.util.List;

import lombok.extern.slf4j.Slf4j;

import com.google.common.collect.Lists;
import com.google.inject.AbstractModule;
import com.google.inject.Guice;
import com.google.inject.Injector;
import com.google.inject.Module;
import com.google.inject.Provides;
import com.google.inject.Scopes;
import com.spotify.ffwd.module.FastForwardModule;
import com.spotify.ffwd.module.PluginContext;
import com.spotify.ffwd.module.PluginContextImpl;

import eu.toolchain.async.AsyncCaller;
import eu.toolchain.async.AsyncFramework;
import eu.toolchain.async.TinyAsync;
import eu.toolchain.async.caller.DirectAsyncCaller;

@Slf4j
public class AgentCore {
    private final List<Class<? extends FastForwardModule>> modules;

    private AgentCore(final List<Class<? extends FastForwardModule>> modules) {
        this.modules = modules;
    }

    public void run() throws Exception {
        final Injector early = setupEarlyInjector();
        final Injector primary = setupPrimaryInjector(early);

        log.info("Started");
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
    public Injector setupPrimaryInjector(final Injector early) {
        final List<Module> modules = Lists.newArrayList();

        modules.add(new AbstractModule() {
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

            @Override
            protected void configure() {
            }
        });

        return early.createChildInjector(modules);
    }

    public static Builder builder() {
        return new Builder();
    }

    public static final class Builder {
        private List<Class<? extends FastForwardModule>> modules = Lists.newArrayList();

        public Builder modules(List<Class<? extends FastForwardModule>> modules) {
            if (modules == null)
                throw new IllegalArgumentException("'modules' must not be null");

            this.modules = modules;
            return this;
        }

        public AgentCore build() {
            return new AgentCore(modules);
        }
    }
}
