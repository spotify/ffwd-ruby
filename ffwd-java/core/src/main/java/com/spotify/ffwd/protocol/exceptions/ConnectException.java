package com.spotify.ffwd.protocol.exceptions;

public class ConnectException extends Exception {
    private static final long serialVersionUID = 6106571638722651596L;

    public ConnectException(String message) {
        super(message);
    }

    public ConnectException(String message, Throwable cause) {
        super(message, cause);
    }
}
