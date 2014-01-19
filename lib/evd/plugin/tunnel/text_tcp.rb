require 'eventmachine'
require 'base64'
require 'json'

require_relative 'base_tcp'

require_relative '../../connection'

module EVD::Plugin::Tunnel
  class TextTCP < EVD::Connection
    include EVD::Logging
    include EM::Protocols::LineText2
    include BaseTCP

    def receive_line line
      if not @metadata
        receive_metadata JSON.load(line)
        return
      end

      protocol, port, addr, data = line.split(' ', 4)

      unless protocol and port and addr
        log.error "Invalid tunneling frame (#{line.size} bytes)"
        return
      end

      begin
        peer_host, peer_port = addr.split(':', 2)
        port = port.to_i
        peer_port = peer_port.to_i
        data = Base64.decode64(data)
      rescue => e
        log.error "Invalid tunneling frame (#{line.size} bytes, last part not decodable)", e
        return
      end

      id = [protocol, port]
      addr = [peer_host, peer_port]
      send_frame id, addr, data
    end
  end

end
