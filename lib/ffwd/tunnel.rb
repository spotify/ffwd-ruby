require_relative 'lifecycle'

require_relative 'tunnel/tcp'
require_relative 'tunnel/udp'

module FFWD
  module Tunnel
    class Plugin
      def subscribe protocol, port, &block
        raise "Not implemented: subscribe"
      end

      def dispatch ip, addr, data
        raise "Not implemented: dispatch"
      end
    end
  end

  FAMILIES = {
    :tcp => Tunnel::TCP,
    :udp => Tunnel::UDP
  }

  def self.tunnel family, port, core, plugin, log, handler, args
    impl = FAMILIES[family]
    raise "Unsupported family: #{family}" if impl.nil?
    return impl.new port, core, plugin, log, handler, args
  end
end
