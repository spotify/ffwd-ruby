require_relative '../../core_emitter'
require_relative '../../core_processor'
require_relative '../../plugin_channel'

module EVD::Plugin::Tunnel
  module BaseTCP
    def initialize input, output, protocol_type, core
      @input = input
      @output = output
      @protocol_type = protocol_type
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

    def parse_protocol protocol
      return Socket::SOCK_STREAM if protocol == :tcp
      return Socket::SOCK_DGRAM if protocol == :udp
      raise "Unsupported protocol: #{protocol}"
    end

    def subscribe protocol, port, &block
      protocol = parse_protocol(protocol)
      id = [protocol, port]

      if @subs[id]
        raise "Only one plugin at a time can tunnel port '#{port}'"
      end

      @subs[id] = block
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

    def metadata?
      not @metadata.nil?
    end

    def receive_metadata data
      @metadata = read_metadata data

      input = EVD::PluginChannel.new 'tunnel'

      @core.tunnels.each do |t|
        t.start input, @output, self
      end

      response = {:type => @protocol_type}

      response[:bind] = @subs.keys.map do |protocol, port|
        {:protocol => protocol, :port => port}
      end

      response = JSON.dump(response)

      send_data "#{response}\n"

      # setup a small core
      emitter = EVD::CoreEmitter.new @output, @metadata
      @processor = EVD::CoreProcessor.new emitter, @core.processors
      @processor.start input

      @debug_id = "tunnel.input/#{get_peer}"
      @core.debug.monitor @debug_id, input, EVD::Debug::Input
    end

    def send_frame id, addr, data
      if s = @subs[id]
        s.call id, addr, data
      else
        log.error "Nothing listening on #{id}'"
      end
    end
  end
end
