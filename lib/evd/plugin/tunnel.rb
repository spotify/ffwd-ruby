require 'eventmachine'
require 'base64'

require_relative '../core_emitter'
require_relative '../logging'
require_relative '../logging'
require_relative '../plugin'
require_relative '../plugin_channel'
require_relative '../protocol'
require_relative '../connection'
require_relative '../debug'

module EVD::Plugin::Tunnel
  include EVD::Plugin
  include EVD::Logging

  register_plugin "tunnel"

  class ConnectionTCP < EVD::Connection
    include EVD::Logging
    include EM::Protocols::LineText2

    def initialize input, output, core, log
      @input = input
      @output = output
      @log = log
      @core = core
      @subs = {}
      @processor = nil
      @debug_id = nil
    end

    def get_peer
      peer = get_peername
      port, ip = Socket.unpack_sockaddr_in(peer)
      "#{ip}:#{port}"
    end

    def unbind
      log.info "Shutting down tunnel connection"
      @processor.stop if @processor
      @processor = nil
      @core.debug.unmonitor @debug_id if @debug_id
      @debug_id = nil
    end

    def subscribe protocol, port, &block
      id = [protocol.to_s, port]

      if @subs[id]
        raise "Only one plugin at a time can tunnel port '#{port}'"
      end

      @subs[id] = block
    end

    def dispatch protocol, port, peer, data
      addr = "#{peer[0]}:#{peer[1]}"
      data = Base64.encode64(data)
      send_data "#{protocol} #{port} #{addr} #{data}\n"
    end

    def read_metadata data
      d = {}

      d[:tags] = EVD.merge_sets @core.tags, data["tags"]
      d[:attributes] = EVD.merge_sets @core.attributes, data["attributes"]

      if host = data["host"]
        d[:host] = host
      end

      if ttl = data["ttl"]
        d[:ttl] = ttl
      end

      d
    end

    def receive_line line
      if not @metadata
        @metadata = read_metadata JSON.load(line)

        input = EVD::PluginChannel.new 'tunnel'

        @core.tunnels.each do |t|
          t.start input, @output, self
        end

        response = JSON.dump({:bind => @subs.keys.map do |protocol, port|
          {:protocol => protocol, :port => port}
        end})

        send_data "#{response}\n"

        # setup a small core
        emitter = EVD::CoreEmitter.new @output, @metadata
        @processor = EVD::CoreProcessor.new emitter, @core.processors
        @processor.start input

        @debug_id = "tunnel.input/#{get_peer}"
        @core.debug.monitor @debug_id, input, EVD::Debug::Input
        return
      end

      protocol, port, addr, data = line.split(' ', 4)

      unless protocol and port and addr
        @log.error "Invalid tunneling frame (#{line.size} bytes)"
        return
      end

      begin
        peer_host, peer_port = addr.split(':', 2)
        port = port.to_i
        peer_port = peer_port.to_i
        data = Base64.decode64(data)
      rescue => e
        @log.error "Invalid tunneling frame (#{line.size} bytes, last part not decodable)", e
        return
      end

      addr = [peer_host, peer_port]

      id = [protocol, port]

      if s = @subs[id]
        s.call addr, data
      else
        @log.error "Nothing listening on port #{id}'"
      end
    end
  end

  DEFAULT_HOST = "localhost"
  DEFAULT_PORT = 9000
  DEFAULT_PROTOCOL = 'tcp'

  CONNECTIONS = {:tcp => ConnectionTCP}

  def self.setup_input core, opts={}
    opts[:host] ||= DEFAULT_HOST
    opts[:port] ||= DEFAULT_PORT
    protocol = EVD.parse_protocol(opts[:protocol] || DEFAULT_PROTOCOL)

    unless connection = CONNECTIONS[protocol.family]
      raise "No connection for protocol family: #{protocol.family}"
    end

    if core.tunnels.empty?
      raise "Nothing requires tunneling"
    end

    protocol.bind log, opts, connection, core, log
  end
end
