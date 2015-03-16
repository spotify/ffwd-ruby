package com.spotify.ffwd.kafka;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.google.common.base.Optional;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;

public class KafkaRouter {
    private static final String DEFAULT_ATTRIBUTE = "default";

    private String metricsTopicFormat = "metrics";
    private String eventsTopicFormat = "events";

    private final String routingAttribute;

    public KafkaRouter() {
        this(null);
    }

    @JsonCreator
    public KafkaRouter(@JsonProperty("routingAttribute") final String rountingAttribute) {
        this.routingAttribute = Optional.fromNullable(rountingAttribute).orNull();

        if (this.routingAttribute != null) {
            metricsTopicFormat += "-%s";
            eventsTopicFormat += "-%s";
        }
    }

    public String route(final Event event) {
        if (routingAttribute == null)
            return metricsTopicFormat;

        final String attr = event.getAttributes().get(routingAttribute);

        if (attr != null)
            return String.format(metricsTopicFormat, attr);

        return String.format(metricsTopicFormat, DEFAULT_ATTRIBUTE);
    }

    public String route(final Metric metric) {
        if (routingAttribute == null)
            return metricsTopicFormat;

        final String attr = metric.getAttributes().get(routingAttribute);

        if (attr != null)
            return String.format(metricsTopicFormat, attr);

        return String.format(metricsTopicFormat, DEFAULT_ATTRIBUTE);
    }
}
