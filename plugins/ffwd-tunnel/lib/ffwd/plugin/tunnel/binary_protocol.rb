require 'ffwd/core/emitter'
require 'ffwd/core/interface'
require 'ffwd/core/reporter'
require 'ffwd/lifecycle'
require 'ffwd/logging'
require 'ffwd/plugin_channel'
require 'ffwd/tunnel/plugin'
require 'ffwd/utils'

module FFWD::Plugin::Tunnel
  class BinaryProtocol < FFWD::Tunnel::Plugin
    include FFWD::Logging
    include FFWD::Lifecycle

    Header = Struct.new(
      :protocol, :bindport,
      :family, :ip, :port,
      :datasize
    )

    HEADER_FORMAT = 'CnCa16nn'
    HEADER_LENGTH = 24

    def initialize core, connection
      @connection = connection
      @subs = {}
      @input = FFWD::PluginChannel.build 'tunnel_input'

      @metadata = nil
      @processor = nil
      @channel_id = nil
      @statistics_id = nil
      @header = nil

      starting do
        raise "no metadata" if @metadata.nil?

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
        @channel_id = nil
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

    def send_config
      response = {}

      response[:bind] = @subs.keys.map do |protocol, port|
        {:protocol => protocol, :port => port}
      end

      response = JSON.dump(response)
      send_data "#{response}\n"
    end

    def receive_metadata data
      @metadata = read_metadata data
      start
      send_config
    end

    def receive_line line
      raise "already have metadata" if @metadata
      receive_metadata JSON.load(line)
      set_text_mode HEADER_LENGTH
    end

    def receive_binary_data data
      if @header
        tunnel_data @header, data
        @header = nil
        set_text_mode HEADER_LENGTH
        return
      end

      fields = data.unpack HEADER_FORMAT
      @header = Header.new(*fields)

      if @header.datasize > 0
        set_text_mode @header.datasize
      else
        tunnel_data @header, nil
        @header = nil
        set_text_mode HEADER_LENGTH
      end
    end

    def dispatch id, addr, data
      protocol, bindport = id
      family, ip, port = addr
      header = [protocol, bindport, family, ip, port, data.size]
      header = header.pack HEADER_FORMAT
      frame = header + data
      send_data frame
    end

    def tunnel_data header, data
      id = [header.protocol, header.bindport]
      addr = [header.family, header.ip, header.port]

      if s = @subs[id]
        s.call id, addr, data
      else
        log.error "Nothing listening on #{id}"
      end
    end
  end
end
