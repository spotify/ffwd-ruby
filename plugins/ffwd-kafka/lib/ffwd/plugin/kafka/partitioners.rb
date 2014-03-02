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

module FFWD::Plugin::Kafka
  # Use the key for partitioning.
  module KeyPartitioner
    def self.partition d
      d.key
    end
  end

  # Use the host for partitioning.
  module HostPartitioner
    def self.partition d
      d.host
    end
  end

  # Use a custom attribute for partitioning.
  class AttributePartitioner
    DEFAULT_ATTRIBUTE = :site

    OPTIONS = [
      FFWD::Plugin.option(
        :attribute, :default => DEFAULT_ATTRIBUTE,
        :help => [
          "Attribute to use when the partitioner is set to :attribute."
        ]
      ),
    ]

    def self.build opts
      attr = opts[:attribute] || DEFAULT_ATTRIBUTE
      new attr
    end

    def initialize attr
      @attr = attr.to_sym
      @attr_s = attr.to_s
    end

    # currently there is an issue where you can store both symbols and string
    # as attribute keys, we need to take that into account.
    def partition d
      if v = d.attributes[@attr]
        return v
      end

      d.attributes[@attr_s]
    end
  end

  def self.build_partitioner type, opts
    if type == :host
      return HostPartitioner
    end

    if type == :key
      return KeyPartitioner
    end

    return AttributePartitioner.build opts
  end
end
