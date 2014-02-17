require_relative 'tunnel/tcp'
require_relative 'tunnel/udp'

module FFWD
  FAMILIES = {:tcp => Tunnel::TCP, :udp => Tunnel::UDP}

  def self.tunnel family, port, core, plugin, log, handler, args
    impl = FAMILIES[family]
    raise "Unsupported family: #{family}" if impl.nil?
    return impl.new port, core, plugin, log, handler, args
  end
end
