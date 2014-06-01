require 'ffwd/tunnel/plugin'

module FFWD::Plugin::Tunnel
  class BindUDP
    class Handle < FFWD::Tunnel::Plugin::Handle
      attr_reader :addr

      def initialize bind, addr
        @bind = bind
        @addr = addr
      end

      def send_data data
        @bind.send_data @addr, data
      end
    end

    def initialize port, family, tunnel, block
      @port = port
      @family = family
      @tunnel = tunnel
      @block = block
    end

    def send_data addr, data
      @tunnel.send_data Socket::SOCK_DGRAM, @family, @port, addr, data
    end

    def data! addr, data
      handle = Handle.new self, addr
      @block.call handle, data
    end
  end
end
