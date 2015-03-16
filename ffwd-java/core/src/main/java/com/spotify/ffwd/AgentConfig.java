package com.spotify.ffwd;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Map;
import java.util.Set;

import lombok.Data;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.google.common.base.Optional;
import com.google.common.collect.Maps;
import com.google.common.collect.Sets;
import com.spotify.ffwd.input.InputManagerModule;
import com.spotify.ffwd.output.OutputManagerModule;

@Data
public class AgentConfig {
    public static final int DEFAULT_ASYNC_THREADS = 20;
    public static final int DEFAULT_BOSS_THREADS = 4;
    public static final int DEFAULT_WORKER_THREADS = 20;

    public static final Map<String, String> DEFAULT_ATTRIBUTES = Maps.newHashMap();
    public static final Set<String> DEFAULT_TAGS = Sets.newHashSet();
    public static final String DEFAULT_QLOG = "./qlog/";

    private final InputManagerModule input;
    private final OutputManagerModule output;
    private final int asyncThreads;
    private final int bossThreads;
    private final int workerThreads;
    private final Map<String, String> attributes;
    private final Set<String> tags;
    private final long ttl;
    private final Path qlog;

    @JsonCreator
    public AgentConfig(@JsonProperty("input") InputManagerModule input,
            @JsonProperty("output") OutputManagerModule output, @JsonProperty("asyncThreads") Integer asyncThreads,
            @JsonProperty("bossThreads") Integer bossThreads, @JsonProperty("workerThreads") Integer workerThreads,
            @JsonProperty("attributes") Map<String, String> attributes, @JsonProperty("tags") Set<String> tags,
            @JsonProperty("ttl") Long ttl, @JsonProperty("qlog") String qlog) {
        this.input = Optional.fromNullable(input).or(InputManagerModule.supplyDefault());
        this.output = Optional.fromNullable(output).or(OutputManagerModule.supplyDefault());
        this.asyncThreads = Optional.fromNullable(asyncThreads).or(DEFAULT_ASYNC_THREADS);
        this.bossThreads = Optional.fromNullable(workerThreads).or(DEFAULT_BOSS_THREADS);
        this.workerThreads = Optional.fromNullable(workerThreads).or(DEFAULT_WORKER_THREADS);
        this.attributes = Optional.fromNullable(attributes).or(DEFAULT_ATTRIBUTES);
        this.tags = Optional.fromNullable(tags).or(DEFAULT_TAGS);
        this.ttl = Optional.fromNullable(ttl).or(0l);
        this.qlog = Paths.get(Optional.fromNullable(qlog).or(DEFAULT_QLOG));
    }
}