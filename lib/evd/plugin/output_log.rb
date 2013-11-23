require 'evd/plugin'
require 'evd/logging'

module EVD::Plugin
  module Log
    include EVD::Plugin
    include EVD::Logging

    register_plugin "log"

    class OutputLog
      include EVD::Logging

      def initialize(prefix)
        @prefix = prefix
      end

      def setup(buffer)
        buffer.pop do |event|
          process event
          setup buffer
        end
      end

      def process(event)
        log.info "#{@prefix}: Output: #{event}"
      end
    end

    def self.output_setup(opts={})
      prefix = opts[:prefix] || "(no prefix)"
      OutputLog.new prefix
    end
  end
end
