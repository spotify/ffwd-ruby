module EventMachine
  module Protocols
    # ObjectProtocol allows for easy communication using marshaled ruby objects
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
        p data

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

        p obj
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
