require 'eventmachine'

require_relative '../logging'
require_relative '../plugin'
require_relative '../protocol'

module EVD::Plugin
  module Syslog
    include EVD::Plugin
    include EVD::Logging

    register_plugin "syslog"

    class Connection < EM::Connection
      include EM::Protocols::LineText2

      def initialize(buffer)
        @buffer = buffer
      end

      def receive_line(data)
        log.info "received: #{data}"
      end
    end

    def self.input_setup(opts={})
      protocol = EVD.parse_protocol(opts[:protocol] || "tcp")
      protocol.listen log, opts, Connection
    end
  end
end
