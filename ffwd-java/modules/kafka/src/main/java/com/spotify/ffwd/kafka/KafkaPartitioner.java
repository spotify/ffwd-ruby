package com.spotify.ffwd.kafka;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;
import com.google.common.base.Optional;
import com.google.common.base.Supplier;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;

@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, include = JsonTypeInfo.As.PROPERTY, property = "type")
@JsonSubTypes({ @JsonSubTypes.Type(value = KafkaPartitioner.Attribute.class, name = "attribute"),
        @JsonSubTypes.Type(value = KafkaPartitioner.Hashed.class, name = "static") })
public interface KafkaPartitioner {
    public String partition(final Event event);

    public String partition(final Metric metric);

    public static class Attribute implements KafkaPartitioner {
        private static final String DEFAULT_ATTRIBUTE = "site";

        private final String attribute;

        @JsonCreator
        public Attribute(@JsonProperty("attribute") final String attribute) {
            this.attribute = Optional.fromNullable(attribute).or(DEFAULT_ATTRIBUTE);
        }

        @Override
        public String partition(final Event event) {
            final String attr = event.getAttributes().get(attribute);

            if (attr != null)
                return attr;

            throw new IllegalArgumentException(String.format("missing attribute '%s' for event %s", attribute, event));
        }

        @Override
        public String partition(final Metric metric) {
            final String attr = metric.getAttributes().get(attribute);

            if (attr != null)
                return attr;

            throw new IllegalArgumentException(String.format("missing attribute '%s' for metric %s", attribute, metric));
        }

        public static Supplier<KafkaPartitioner> supplier() {
            return new Supplier<KafkaPartitioner>() {
                @Override
                public KafkaPartitioner get() {
                    return new Attribute(null);
                }
            };
        }
    }

    public static class Hashed implements KafkaPartitioner {
        @JsonCreator
        public Hashed() {
        }

        @Override
        public String partition(final Event event) {
            return Integer.toHexString(event.hashCode());
        }

        @Override
        public String partition(final Metric metric) {
            return Integer.toHexString(metric.hashCode());
        }

        public static Supplier<KafkaPartitioner> supplier() {
            return new Supplier<KafkaPartitioner>() {
                @Override
                public KafkaPartitioner get() {
                    return new Hashed();
                }
            };
        }
    }
}
