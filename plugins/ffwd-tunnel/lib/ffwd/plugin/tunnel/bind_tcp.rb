require 'ffwd/tunnel/plugin'

module FFWD::Plugin::Tunnel
  class BindTCP
    class Handle < FFWD::Tunnel::Plugin::Handle
      attr_reader :addr

      def initialize bind, addr
        @bind = bind
        @addr = addr
        @close = nil
        @data = nil
      end

      def send_data data
        @bind.send_data @addr, data
      end

      def close &block
        @close = block
      end

      def data &block
        @data = block
      end

      def recv_close
        return if @close.nil?
        @close.call
        @close = nil
        @data = nil
      end

      def recv_data data
        return if @data.nil?
        @data.call data
      end
    end

    def initialize port, family, tunnel, block
      @port = port
      @family = family
      @tunnel = tunnel
      @block = block
      @handles = {}
    end

    def open addr
      raise "Already open: #{addr}" if @handles[addr]
      handle = @handles[addr] = Handle.new self, addr
      @block.call handle
    end

    def close addr
      raise "Not open: #{addr}" unless handle = @handles[addr]
      handle.recv_close
      @handles.delete addr
    end

    def data addr, data
      return if data.empty?

      unless handle = @handles[addr]
        raise "Not available: #{addr}"
      end

      handle.recv_data data
    end

    def send_data addr, data
      @tunnel.send_data Socket::SOCK_STREAM, @family, @port, addr, data
    end
  end
end
