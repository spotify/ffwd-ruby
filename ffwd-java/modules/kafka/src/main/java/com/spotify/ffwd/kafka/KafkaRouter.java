package com.spotify.ffwd.kafka;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.google.common.base.Optional;
import com.spotify.ffwd.model.Event;
import com.spotify.ffwd.model.Metric;


public class KafkaRouter {

    private String metricsTopicFormat = "metrics";
    private String eventsTopicFormat = "events";

    private final String rountingAttribute;

    public KafkaRouter() {
        this(null);
    }

    @JsonCreator
    public KafkaRouter(@JsonProperty("routingAttribute") final String rountingAttribute) {
        this.rountingAttribute = Optional.fromNullable(rountingAttribute).orNull();
        if (this.rountingAttribute != null) {
            metricsTopicFormat += "-%s";
            eventsTopicFormat += "-%s";
        }
    }

    public String getEventTopic(final Event event) {
        if (rountingAttribute == null) {
            return eventsTopicFormat;
        }
        String attr = event.getAttributes().get(rountingAttribute);
        if (attr == null) {
            attr = "default";
        }

        return String.format(eventsTopicFormat, attr);
    }

    public String getMetricTopic(final Metric metric) {
        if (rountingAttribute == null) {
            return metricsTopicFormat;
        }
        String attr = metric.getAttributes().get(rountingAttribute);
        if (attr == null) {
            attr = "default";
        }

        return String.format(metricsTopicFormat, attr);
    }
}
