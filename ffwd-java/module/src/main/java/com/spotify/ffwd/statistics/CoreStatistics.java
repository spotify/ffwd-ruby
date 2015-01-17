package com.spotify.ffwd.statistics;

public interface CoreStatistics {
    public InputManagerStatistics newInputManager();

    public OutputManagerStatistics newOutputManager();
}