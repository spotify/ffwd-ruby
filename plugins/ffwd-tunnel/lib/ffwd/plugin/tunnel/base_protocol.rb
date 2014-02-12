require 'ffwd/utils'
require 'ffwd/logging'
require 'ffwd/plugin_channel'
require 'ffwd/core_emitter'
require 'ffwd/core_processor'

module FFWD::Plugin::Tunnel
  class BaseProtocol
    include FFWD::Logging

    def initialize core, output, connection
      @core = core
      @output = output
      @connection = connection
      @metadata = nil
      @processor = nil
      @channel_id = nil
      @statistics_id = nil
      @subs = {}
    end

    def send_data data
      @connection.send_data data
    end

    def set_text_mode size
      @connection.set_text_mode size
    end

    def tunnel_frame id, addr, data
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

      if @core.debug and @channel_id
        @core.debug.unmonitor @channel_id
      end

      if @core.statistics and @statistics_id
        @core.statistics.unregister @statistics_id
      end

      @metadata = nil
      @processor = nil
      @channel_id = nil
      @statistics_id = nil
      @subs = {}
    end

    def read_metadata data
      d = {}

      d[:tags] = FFWD.merge_sets @core.tags, data["tags"]
      d[:attributes] = FFWD.merge_sets @core.attributes, data["attributes"]

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

      input = FFWD::PluginChannel.new 'tunnel_input'

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
      emitter = FFWD::CoreEmitter.build @output, @metadata
      @processor = FFWD::CoreProcessor.build input, emitter, @core.processors

      reporters = [input]
      reporters += @processor

      @reporter = FFWD::CoreReporter.new reporters

      if host = @metadata[:host]
        @statistics_id = "tunnel/#{host}"
        @channel_id = "tunnel.input/#{host}"
      else
        @statistics_id = "tunnel/#{@connection.get_peer}"
        @channel_id = "tunnel.input/#{@connection.get_peer}"
      end

      if @core.debug
        @core.debug.monitor @channel_id, input, FFWD::Debug::Input
      end

      if @core.statistics
        @core.statistics.register @statistics_id, @reporter
      end
    end
  end
end
