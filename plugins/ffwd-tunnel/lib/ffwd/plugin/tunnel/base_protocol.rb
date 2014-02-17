require 'ffwd/core/emitter'
require 'ffwd/core/interface'
require 'ffwd/core/reporter'
require 'ffwd/lifecycle'
require 'ffwd/logging'
require 'ffwd/plugin_channel'
require 'ffwd/tunnel/plugin'
require 'ffwd/utils'

module FFWD::Plugin::Tunnel
  class BaseProtocol < FFWD::Tunnel::Plugin
    include FFWD::Logging
    include FFWD::Lifecycle

    def initialize core, connection
      @connection = connection
      @metadata = nil
      @processor = nil
      @channel_id = nil
      @statistics_id = nil
      @subs = {}
      @input = FFWD::PluginChannel.build 'tunnel_input'

      starting do
        if @metadata.nil?
          raise "no metadata"
        end

        if host = @metadata[:host]
          @statistics_id = "tunnel/#{host}"
          @channel_id = "tunnel.input/#{host}"
        else
          @statistics_id = "tunnel/#{@connection.get_peer}"
          @channel_id = "tunnel.input/#{@connection.get_peer}"
        end

        # setup a small core
        emitter = FFWD::Core::Emitter.build @core.output, @metadata
        @processor = FFWD::Core::Processor.build @input, emitter, @core.processors

        @reporter = FFWD::Core::Reporter.new [@input, @processor]

        if @core.debug
          @core.debug.monitor @channel_id, @input, FFWD::Debug::Input
        end

        if @core.statistics
          @core.statistics.register @statistics_id, @reporter
        end
      end

      stopping do
        if @core.statistics and @statistics_id
          @core.statistics.unregister @statistics_id
          @statistics_id = nil
        end

        @metadata = nil
        @processor = nil
        @subs = {}
      end

      @core = core.reconnect @input

      @core.tunnel_plugins.each do |t|
        instance = t.setup @core, self
        instance.depend_on self
      end

      @input.depend_on self
      @core.depend_on self
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

      start

      response = {:type => self.class.type}

      response[:bind] = @subs.keys.map do |protocol, port|
        {:protocol => protocol, :port => port}
      end

      response = JSON.dump(response)
      send_data "#{response}\n"
    end
  end
end
