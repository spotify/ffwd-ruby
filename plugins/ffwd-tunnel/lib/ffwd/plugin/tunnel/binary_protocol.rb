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
    class TcpBind
      class TcpHandle < FFWD::Tunnel::Plugin::Handle
        def initialize bind, addr
          @bind = bind
          @addr = addr
          @close = nil
          @data = nil
        end

        def dispatch data
          @bind.dispatch @addr, data
        end

        def close &block
          @close = block
        end

        def data &block
          @data = block
        end

        def close!
          return if @close.nil?
          @close.call
        end

        def data! data
          return if @data.nil?
          @data.call data
        end
      end

      def initialize port, family, tunnel, block
        @port = port
        @family = family
        @tunnel = tunnel
        @block = block
        @handles = {}
      end

      def ntop ip
        if @family == Socket::AF_INET
          return ip.unpack("C*").map(&:to_s).join '.'
        end

        if @family == Socket::AF_INET6
          parts = []
          ip.unpack("C*").each_slice(2){|s|
            parts << s.map{|c| c.to_s(16)}.join('')
          }
          return parts.join '::'
        end
      end

      def open addr
        raise "Already open: #{addr}" if @handles[addr]
        handle = @handles[addr] = TcpHandle.new self, addr
        ip, port = addr
        ip = ntop ip
        @block.call [ip, port], handle
      end

      def close addr
        raise "Not open: #{addr}" unless handle = @handles[addr]
        handle.close!
        @handles.delete addr
      end

      def data addr, data
        unless handle = @handles[addr]
          raise "Not available: #{addr}"
        end

        handle.data! data
      end

      def dispatch addr, data
        @tunnel.tcp_dispatch @family, @port, addr, data
      end
    end

    include FFWD::Logging
    include FFWD::Lifecycle

    Header = Struct.new(:length, :type, :port, :family, :protocol)
    HeaderFormat = 'nnnCC'
    HeaderSize = 8

    PeerAddrAfInet = Struct.new(:ip, :port)
    PeerAddrAfInetFormat = "a4n"
    PeerAddrAfInetSize = 6

    PeerAddrAfInet6 = Struct.new(:ip, :port)
    PeerAddrAfInet6Format = "a16n"
    PeerAddrAfInet6Size = 18

    State = Struct.new(:state)
    StateFormat = 'n'
    StateSize = 2

    STATE = 0x0000
    DATA = 0x0001

    OPEN = 0x0000
    CLOSE = 0x0001

    def initialize core, c
      @c = c
      @tcp_bind = {}
      @udp_bind = {}
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
          @statistics_id = "tunnel/#{@c.get_peer}"
          @channel_id = "tunnel.input/#{@c.get_peer}"
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
        @tcp_bind = {}
        @udp_bind = {}
      end

      @core = core.reconnect @input

      @core.tunnel_plugins.each do |t|
        instance = t.setup @core, self
        instance.depend_on self
      end

      @input.depend_on self
      @core.depend_on self
    end

    def tcp port, &block
      @tcp_bind[[port, Socket::AF_INET]] = TcpBind.new(
        port, Socket::AF_INET, self, block)
    end

    def udp port, &block
      @udp_bind[[port, Socket::AF_INET]] = block
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

      tcp = @tcp_bind.keys.map{|port, family|
        {:protocol => Socket::SOCK_STREAM,
         :family => family,
         :port => port}}
      udp = @udp_bind.keys.map{|port, family|
        {:protocol => Socket::SOCK_DGRAM,
         :family => family,
         :port => port}}

      response[:bind] = tcp + udp

      response = JSON.dump(response)
      @c.send_data "#{response}\n"
    end

    def receive_metadata data
      @metadata = read_metadata data
      start
      send_config
    end

    def receive_line line
      raise "already have metadata" if @metadata
      receive_metadata JSON.load(line)
      @c.set_text_mode HeaderSize
    end

    def parse_addr_format family
      if family == Socket::AF_INET
        return PeerAddrAfInetFormat, PeerAddrAfInetSize
      end

      if family == Socket::AF_INET6
        return PeerAddrAfInet6Format, PeerAddrAfInet6Size
      end

      raise "Unsupported address family: #{family}"
    end

    def peer_addr_pack family, addr
      format, size = parse_addr_format family
      return addr.pack(format), size
    end

    def peer_addr_unpack family, data
      format, size = parse_addr_format family
      return data[0,size].unpack(format), size
    end

    def receive_frame header, addr, data
      if header.type == DATA
        tunnel_data header, addr, data
        return
      end

      if header.type == STATE
        state = data.unpack(StateFormat)[0]
        tunnel_state header, addr, state
        return
      end
    end

    def receive_binary_data data
      if @header
        addr, addr_size = peer_addr_unpack @header.family, data
        data = data[addr_size,data.size - addr_size]
        receive_frame @header, addr, data
        @header = nil
        @c.set_text_mode HeaderSize
        return
      end

      fields = data.unpack HeaderFormat
      @header = Header.new(*fields)
      rest = @header.length - HeaderSize
      @c.set_text_mode rest
    end

    def tcp_dispatch family, port, addr, data
      addr_data, addr_size = peer_addr_pack family, addr
      length = HeaderSize + addr_size + data.size
      # Struct.new(:length, :type, :port, :family, :protocol)
      header_data = [
        length, DATA, port, family, Socket::SOCK_STREAM].pack HeaderFormat
      frame = header_data + addr_data + data
      @c.send_data frame
    end

    def tunnel_data header, addr, data
      if header.protocol == Socket::SOCK_DGRAM
        if udp = @udp_bind[[header.port, header.family]]
          udp.call addr, data
        end

        return
      end

      if header.protocol == Socket::SOCK_STREAM
        unless bind = @tcp_bind[[header.port, header.family]]
          log.error "Nothing listening on tcp/#{header.port}"
          return
        end

        bind.data addr, data
        return
      end

      log.error "DATA: Unsupported protocol: #{header.protocol}"
    end

    def tunnel_state header, addr, state
      if header.protocol == Socket::SOCK_DGRAM
        # ignored
        log.error "UDP does not handle: #{state}"
        return
      end

      if header.protocol == Socket::SOCK_STREAM
        unless bind = @tcp_bind[[header.port, header.family]]
          log.error "Nothing listening on tcp/#{header.port}"
          return
        end

        if state == OPEN
          bind.open addr
          return
        end

        if state == CLOSE
          bind.close addr
          return
        end

        log.error "Unknown state: #{state}"
        return
      end

      log.error "STATE: Unsupported protocol: #{header.protocol}"
    end
  end
end
