require 'set'
require 'eventmachine'
require 'base64'

require_relative '../core_emitter'
require_relative '../logging'
require_relative '../logging'
require_relative '../plugin'
require_relative '../plugin_channel'
require_relative '../protocol'

module EVD::Plugin::Tunnel
  include EVD::Plugin
  include EVD::Logging

  register_plugin "tunnel"

  class ConnectionTCP < EM::Connection
    include EVD::Logging
    include EM::Protocols::LineText2

    def initialize input, output, core, log
      @input = input
      @output = output
      @log = log
      @core = core
      @subs = {}
    end

    def subscribe port, &block
      if @subs[port]
        raise "Only one plugin at a time can tunnel port '#{port}'"
      end

      @subs[port] = block
    end

    def read_metadata data
      d = {}

      if tags = data["tags"]
        d[:tags] = tags.to_set
      end

      if attributes = data["attributes"]
        d[:attributes] = attributes
      end

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

        response = JSON.dump({:ports => @subs.keys})

        send_data "#{response}\n"

        # setup a small core
        emitter = EVD::CoreEmitter.new @output, @metadata
        processor = EVD::CoreProcessor.new emitter, @core.processors

        input.event_subscribe do |e|
          processor.process_event e
        end

        input.metric_subscribe do |m|
          processor.process_metric m
        end

        return
      end

      port, data = line.split(' ', 2)

      begin
        port = port.to_i
        data = Base64.decode64(data)
      rescue => e
        log.error "Invalid frame", e
        return
      end

      if s = @subs[port]
        s.call data
      else
        @log.error "Nothing listening on port '#{port}'"
      end
    end
  end

  DEFAULT_HOST = "localhost"
  DEFAULT_PORT = 9000
  DEFAULT_PROTOCOL = 'tcp'

  CONNECTIONS = {:tcp => ConnectionTCP}

  def self.bind core, opts={}
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
