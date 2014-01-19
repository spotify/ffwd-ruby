require_relative '../../utils'
require_relative '../../plugin_channel'
require_relative '../../core_emitter'
require_relative '../../core_processor'

module EVD::Plugin::Tunnel
  class BaseProtocol
    def initialize core, output, conn
      @core = core
      @output = output
      @conn = conn
      @metadata = nil
      @processor = nil
      @debug_id = nil
      @subs = {}
    end

    def send_data data
      @conn.send_data data
    end

    def set_text_mode size
      @conn.set_text_mode size
    end

    def send_frame id, addr, data
      if s = @subs[id]
        s.call id, addr, data
      else
        log.error "Nothing listening on #{id}'"
      end
    end

    def parse_protocol string
      return Socket::SOCK_STREAM if string == :tcp
      return Socket::SOCK_DGRAM if string == :udp
      raise "Unsupported protocol: #{string}"
    end

    def subscribe protocol, port, &block
      protocol = parse_protocol protocol
      id = [protocol, port]

      if @subs[id]
        raise "Only one plugin at a time can tunnel port '#{port}'"
      end

      @subs[id] = block
    end

    def stop
      @processor.stop if @processor
      @core.debug.unmonitor @debug_id if @debug_id
      @metadata = nil
      @processor = nil
      @debug_id = nil
      @subs = {}
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

    def receive_metadata data
      @metadata = read_metadata data

      input = EVD::PluginChannel.new 'tunnel'

      @core.tunnels.each do |t|
        t.start input, @output, self
      end

      response = {:type => self.class.type}

      response[:bind] = @subs.keys.map do |protocol, port|
        {:protocol => protocol, :port => port}
      end

      response = JSON.dump(response)

      send_data "#{response}\n"

      # setup a small core
      emitter = EVD::CoreEmitter.new @output, @metadata
      @processor = EVD::CoreProcessor.new emitter, @core.processors
      @processor.start input

      @debug_id = "tunnel.input/#{@conn.get_peer}"
      @core.debug.monitor @debug_id, input, EVD::Debug::Input
    end

  end
end
