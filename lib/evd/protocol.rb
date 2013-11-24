module EVD
  def self.parse_protocol(original)
    string = original.downcase

    return :udp if string == "udp"
    return :tcp if string == "tcp"

    throw Exception("Unknown protocol '#{original}'")
  end
end
