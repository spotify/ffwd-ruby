# describes the protocol that has to be implemented by a tunnel.

module FFWD::Tunnel
  class Plugin
    # Object type that should be returned by 'tcp'.
    class Handle
      def close &block
        raise "Not implemented: close"
      end

      def data &block
        raise "Not implemented: data"
      end

      def send_data data
        raise "Not implemented: send_data"
      end
    end

    def tcp port, &block
      raise "Not implemented: tcp"
    end

    def udp port, &block
      raise "Not implemented: udp"
    end

    def send_data addr, data
      raise "Not implemented: send_data"
    end
  end
end
