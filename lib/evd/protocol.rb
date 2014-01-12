require_relative 'protocol/udp'
require_relative 'protocol/tcp'
require_relative 'protocol/unix_udp'
require_relative 'protocol/unix_tcp'

module EVD
  def self.parse_protocol(original)
    string = original.downcase

    return UDP if string == "udp"
    return UnixUDP if string == "unix+udp"
    return TCP if string == "tcp"
    return UnixTCP if string == "unix+tcp"

    throw "Unknown protocol '#{original}'"
  end
end
