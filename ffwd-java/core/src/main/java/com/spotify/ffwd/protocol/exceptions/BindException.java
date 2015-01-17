package com.spotify.ffwd.protocol.exceptions;

public class BindException extends Exception {
    private static final long serialVersionUID = 6106571638722651596L;

    public BindException(String message) {
        super(message);
    }

    public BindException(String message, Throwable cause) {
        super(message, cause);
    }
}
