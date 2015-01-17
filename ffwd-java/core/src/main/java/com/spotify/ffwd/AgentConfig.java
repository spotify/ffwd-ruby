package com.spotify.ffwd;

import lombok.Data;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.google.common.base.Optional;
import com.spotify.ffwd.input.InputManagerModule;
import com.spotify.ffwd.output.OutputManagerModule;

@Data
public class AgentConfig {
    private final InputManagerModule input;
    private final OutputManagerModule output;

    @JsonCreator
    public AgentConfig(@JsonProperty("input") InputManagerModule input, @JsonProperty("output") OutputManagerModule output) {
        this.input = Optional.of(input).or(InputManagerModule.supplyDefault());
        this.output = Optional.of(output).or(OutputManagerModule.supplyDefault());
    }
}