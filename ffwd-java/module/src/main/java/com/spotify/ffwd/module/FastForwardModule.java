package com.spotify.ffwd.module;

/**
 * Base interface for external modules.
 *
 * Modules are wired with the early Injector, and has access to all of its dependencies.
 *
 * @author udoprog
 */
public interface FastForwardModule {
    /**
     * Configure the external module.
     *
     * The intention is for the module to inject and setup the hooks which it needs to perform its operation.
     */
    public void setup() throws Exception;
}
