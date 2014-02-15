require 'eventmachine'
require 'base64'
require 'json'

require_relative 'base_protocol'

module FFWD::Plugin::Tunnel
  class TextProtocol < BaseProtocol
    def initialize core, connection
      super core, connection
    end

    def self.type
      :text
    end

    def receive_line line
      if not @metadata
        receive_metadata JSON.load(line)
        return
      end

      protocol, bindport, peerfamily, peeraddr, peerport, data = line.split(' ', 6)

      begin
        protocol = protocol.to_i
        bindport = bindport.to_i
        peerfamily = peerfamily.to_i
        peerport = peerport.to_i
        data = Base64.decode64(data)
      rescue => e
        log.error "Invalid tunneling frame (#{line.size} bytes, last part not decodable)", e
        return
      end

      id = [protocol, bindport]
      addr = [peerfamily, peeraddr, peerport]
      tunnel_frame id, addr, data
    end

    def receive_binary_data data
      raise "receive binary data unsupported"
    end

    def dispatch id, addr, data
      protocol, bindport = id
      peerfamily, peeraddr, peerport = addr
      data = Base64.encode64(data)
      send_data "#{protocol} #{bindport} #{peerfamily} #{peeraddr} #{peerport} #{data}\n"
    end
  end
end
