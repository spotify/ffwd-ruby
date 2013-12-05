require 'evd/plugin'
require 'evd/logging'

module EVD::Plugin
  module Log
    include EVD::Plugin
    include EVD::Logging

    register_plugin "log"

    class Writer
      include EVD::Logging

      def initialize(prefix)
        @prefix = prefix
      end

      def start(buffer)
        buffer.pop do |event|
          process event
          start buffer
        end
      end

      def process(event)
        log.info "(#{@prefix}) Output: #{event.inspect}"
      end
    end

    def self.output_setup(opts={})
      prefix = opts[:prefix] || "no prefix"
      Writer.new prefix
    end
  end
end
