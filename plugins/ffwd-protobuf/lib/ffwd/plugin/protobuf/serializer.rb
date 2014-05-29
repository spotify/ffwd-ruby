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

require_relative 'serializer/protocol0'

module FFWD::Plugin::Protobuf::Serializer
  VERSIONS = {
    0 => Protocol0
  }

  LATEST_VERSION = 0

  def self.dump_frame string
    [LATEST_VERSION, string.length + 8].pack("NN") + string
  end

  def self.load_frame string
    if string.length < 8
      raise "Frame too small, expected at least 8 bytes but got #{string.length}"
    end

    version = string[0..3].unpack("N")[0]
    length = string[4..7].unpack("N")[0]

    unless impl = VERSIONS[version]
      raise "Unsupported protocol version #{version}, latest is #{LATEST_VERSION}"
    end

    if length != string.length
      raise "Message length invalid, expected #{length} but got #{string.length}"
    end

    [impl, string[8..length]]
  end

  def self.dump_event event
    unless impl = VERSIONS[LATEST_VERSION]
      raise "No implementation for latest version: #{LATEST_VERSION}"
    end

    dump_frame impl.dump_event event
  end

  def self.dump_metric metric
    unless impl = VERSIONS[LATEST_VERSION]
      raise "No implementation for latest version: #{LATEST_VERSION}"
    end

    dump_frame impl.dump_metric metric
  end

  def self.load string
    impl, string = load_frame string

    impl.load string do |type, data|
      yield type, data
    end
  end
end
