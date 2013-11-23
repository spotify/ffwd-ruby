module EVD
  module TCPProtocol
    def self.name
      "tcp"
    end

    def self.listen(host, port, handler=nil, *args, &block)
      EventMachine.start_server(host, port, handler, *args, &block)
    end
  end

  module UDPProtocol
    def self.name
      "udp"
    end

    def self.listen(host, port, handler=nil, *args, &block)
      EventMachine.open_datagram_socket(host, port, handler, *args, &block)
    end
  end

  def self.parse_protocol(original)
    string = original.downcase

    return UDPProtocol if string == "udp"
    return TCPProtocol if string == "tcp"

    throw Exception("Unknown protocol '#{original}'")
  end
end
