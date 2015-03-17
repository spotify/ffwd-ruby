package com.spotify.ffwd;

import java.util.ArrayList;
import java.util.List;

import lombok.extern.slf4j.Slf4j;

import com.spotify.ffwd.module.FastForwardModule;

@Slf4j
public class FastForwardAgent {
    public static void main(String argv[]) {
        final List<Class<? extends FastForwardModule>> modules = new ArrayList<>();

        // built-in core
        modules.add(com.spotify.ffwd.debug.DebugModule.class);
        modules.add(com.spotify.ffwd.json.JsonModule.class);
        modules.add(com.spotify.ffwd.protobuf.ProtobufModule.class);
        modules.add(com.spotify.ffwd.serializer.BuiltInSerializers.class);

        // additional
        modules.add(com.spotify.ffwd.kafka.KafkaModule.class);
        modules.add(com.spotify.ffwd.riemann.RiemannModule.class);

        final AgentCore core = AgentCore.builder().modules(modules).build();

        try {
            core.run();
        } catch (Exception e) {
            log.error("Error in agent, exiting", e);
            System.exit(1);
            return;
        }

        System.exit(0);
    }
}
