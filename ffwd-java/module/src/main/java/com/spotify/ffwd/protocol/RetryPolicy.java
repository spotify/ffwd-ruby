package com.spotify.ffwd.protocol;

import java.util.concurrent.TimeUnit;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;
import com.fasterxml.jackson.annotation.JsonTypeName;
import com.google.common.base.Optional;

@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, include = JsonTypeInfo.As.PROPERTY, property = "type")
@JsonSubTypes({ @JsonSubTypes.Type(RetryPolicy.Constant.class), @JsonSubTypes.Type(RetryPolicy.Exponential.class),
        @JsonSubTypes.Type(RetryPolicy.Linear.class) })
public interface RetryPolicy {
    /**
     * Get the required delay in milliseconds.
     *
     * A value of {@code 0} or less will cause no delay.
     *
     * @param attempt A zero-based number indicating the current attempt.
     */
    public long delay(int attempt);

    /**
     * A retry policy with a constant delay.
     */
    @JsonTypeName("constant")
    public static class Constant implements RetryPolicy {
        public static final long DEFAULT_VALUE = TimeUnit.MILLISECONDS.convert(10, TimeUnit.SECONDS);

        private final long value;

        @JsonCreator
        public Constant(@JsonProperty("value") Long value) {
            this.value = Optional.fromNullable(value).or(DEFAULT_VALUE);
        }

        @Override
        public long delay(int attempt) {
            return value;
        }
    }

    /**
     * A retry policy that increases delay exponentially.
     */
    @JsonTypeName("exponential")
    public static class Exponential implements RetryPolicy {
        public static final long DEFAULT_INITIAL = TimeUnit.MILLISECONDS.convert(2, TimeUnit.SECONDS);
        public static final long DEFAULT_MAX = TimeUnit.MILLISECONDS.convert(5, TimeUnit.MINUTES);

        private final long initial;
        private final long max;

        @JsonCreator
        public Exponential(@JsonProperty("initial") Long initial, @JsonProperty("max") Long max) {
            this.initial = Optional.fromNullable(initial).or(DEFAULT_INITIAL);
            this.max = Optional.fromNullable(max).or(DEFAULT_MAX);
        }

        public Exponential() {
            this(null, null);
        }

        @Override
        public long delay(int attempt) {
            final long suggestion = initial * (long) Math.pow(2, attempt);
            return Math.min(max, suggestion);
        }
    }

    /**
     * A retry policy that increases delay linearly.
     */
    @JsonTypeName("linear")
    public static class Linear implements RetryPolicy {
        public static final long DEFAULT_VALUE = TimeUnit.MILLISECONDS.convert(2, TimeUnit.SECONDS);
        public static final long DEFAULT_MAX = TimeUnit.MILLISECONDS.convert(5, TimeUnit.MINUTES);

        private final long value;
        private final long max;

        @JsonCreator
        public Linear(@JsonProperty("value") Long value, @JsonProperty("max") Long max) {
            this.value = Optional.fromNullable(value).or(DEFAULT_VALUE);
            this.max = Optional.fromNullable(max).or(DEFAULT_MAX);
        }

        @Override
        public long delay(int attempt) {
            final long suggestion = value * (attempt + 1);
            return Math.min(max, suggestion);
        }
    }
}
