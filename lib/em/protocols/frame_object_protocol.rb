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

module EventMachine
  module Protocols
    # FrameObjectProtocol is a reimplementation of ObjectProtocol suitable for UDP
    #
    #  module RubyServer
    #    include EM::P::FrameObjectProtocol
    #
    #    def receive_object obj
    #      send_object({'you said' => obj})
    #    end
    #  end
    #
    module FrameObjectProtocol
      # By default returns Marshal, override to return JSON or YAML, or any
      # other serializer/deserializer responding to #dump and #load.
      def serializer
        Marshal
      end

      # @private
      def receive_data data
        begin
          if data.size < 4
            raise "Received invalid datagram, datagram way too small"
          end

          size=data.unpack('N').first

          if data.size != 4+size
            actual_size = data.size-4
            raise "Received invalid datagram: expected size=#{size}, actual size=#{actual_size}"
          end

          obj = serializer.load data[4..-1]
        rescue => e
          handle_exception(data, e)
          return
        end

        receive_object obj
      end

      # Invoked with ruby objects received over the network
      def receive_object obj
        # stub
      end

      # Sends a ruby object over the network
      def send_object obj
        data = serializer.dump(obj)
        send_data [data.respond_to?(:bytesize) ? data.bytesize : data.size, data].pack('Na*')
      end

      # Invoked whenever FrameObjectProtocol fails to deserialize an object
      def handle_exception datagram, e
        # stub
      end
    end
  end
end
