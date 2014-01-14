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

      def initialize input, output
        @input = input
      end

      def receive_line data
        log.info "received: #{data}"
      end
    end

    def self.bind core, opts={}
      protocol = EVD.parse_protocol(opts[:protocol] || "tcp")
      protocol.bind log, opts, Connection
    end
  end
end
