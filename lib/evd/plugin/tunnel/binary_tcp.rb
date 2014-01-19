require 'eventmachine'
require 'json'

require_relative 'base_tcp'

require_relative '../../connection'

module EVD::Plugin::Tunnel
  class BinaryTCP < EVD::Connection
    include EM::Protocols::LineText2
    include EVD::Logging
    include BaseTCP

    Header = Struct.new(
      :protocol,
      :bindport,
      :peerfamily,
      :peeraddr,
      :peerport,
      :datalen,
    )

    HEADER_FORMAT = 'CnCa16nn'
    HEADER_LENGTH = 24

    def receive_line line
      raise "already have metadata" if @metadata
      receive_metadata JSON.load(line)
      set_text_mode HEADER_LENGTH
    end

    def read_protocol b
      return "tcp" if b == 0
      return "udp" if b == 1
      raise "unknown protocol"
    end

    def receive_binary_data data
      unless (@header ||= nil)
        @header = Header.new(*data.unpack(HEADER_FORMAT))
        set_text_mode @header.datalen
        return
      end

      id = [@header.protocol, @header.bindport]
      addr = [@header.peerfamily, @header.peeraddr, @header.peerport]
      send_frame id, addr, data

      @header = nil
      set_text_mode HEADER_LENGTH
    end

    def dispatch id, addr, data
      protocol, bindport = id
      peerfamily, peeraddr, peerport = addr
      header = [protocol, bindport, peerfamily, peeraddr, peerport, data.size]
      header = header.pack HEADER_FORMAT
      frame = header + data

      send_data frame
    end
  end
end
