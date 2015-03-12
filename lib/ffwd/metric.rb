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

require_relative 'utils'

module FFWD
  # Struct used to define all fields related to a metric.
  MetricStruct = Struct.new(
    # The time at which the metric was collected.
    :time,
    # The unique key of the metric.
    :key,
    # A numeric value associated with the metric.
    :value,
    # The host from which the metric originated.
    :host,
    # The source metric this metric was derived from (if any).
    :source,
    # Tags associated to the metric.
    :tags,
    # Attributes (extra fields) associated to the metric.
    :external_attr,
    # Attributes which are statically provided by the internal implementation.
    :fixed_attr
  )

  # A convenience class for each individual metric.
  class Metric < MetricStruct
    def self.make opts={}
      new(opts[:time], opts[:key], opts[:value], opts[:host], opts[:source],
          opts[:tags], opts[:external_attr], opts[:fixed_attr])
    end

    # maintained for backwards compatibility, but implementors are encouraged
    # to use internal/external attributes directly.
    def attributes
      FFWD.merge_hashes fixed_attr, external_attr
    end

    # Convert metric to a sparse hash.
    def to_h
      d = {}
      d[:time] = time.to_i if time
      d[:key] = key if key
      d[:value] = value if value
      d[:host] = host if host
      d[:source] = source if source
      d[:tags] = tags.to_a if tags

      if a = attributes
        d[:attributes] = a
      end

      d
    end
  end
end
