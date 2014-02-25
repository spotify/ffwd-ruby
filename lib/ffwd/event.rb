# $LICENSE
# Copyright 2013-2014 Spotify AB. All rights reserved.
#
# The contents of this file are licensed under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with the
# License. You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

module FFWD
  # Struct used to define all fields related to an event.
  EventStruct = Struct.new(
    # The time at which the event was collected.
    :time,
    # The unique key of the event.
    :key,
    # A numeric value associated with the event.
    :value,
    # The host from which the event originated.
    :host,
    # The source event this event was derived from (if any).
    :source,
    # A state associated to the event.
    :state,
    # A description associated to the event.
    :description,
    # A time to live associated with the event.
    :ttl,
    # Tags associated with the event.
    :tags,
    # Attributes (extra fields) associated with the event.
    :attributes
  )

  # A convenience class for each individual event.
  class Event < EventStruct
    def self.make opts = {}
      new(opts[:time], opts[:key], opts[:value], opts[:host], opts[:source],
          opts[:state], opts[:description], opts[:ttl], opts[:tags],
          opts[:attributes])
    end

    # Convert event to a sparse hash.
    def to_h
      d = {}
      d[:time] = time.to_i if time
      d[:key] = key if key
      d[:value] = value if value
      d[:host] = host if host
      d[:source] = source if source
      d[:state] = state if state
      d[:description] = description if description
      d[:ttl] = ttl if ttl
      d[:tags] = tags.to_a if tags
      d[:attributes] = attributes if attributes
      d
    end
  end
end
