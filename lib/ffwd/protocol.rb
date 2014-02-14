require_relative 'protocol/udp'
require_relative 'protocol/tcp'

module FFWD
  def self.parse_protocol(original)
    string = original.downcase

    return UDP if string == "udp"
    return TCP if string == "tcp"

    throw "Unknown protocol '#{original}'"
  end
end
