require 'evd/event'
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
        @p = if prefix
          "#{prefix} "
        else
          ""
        end
      end

      def start(channel)
        channel.subscribe do |e|
          log.info "#{@p}#{EVD.event_s e}"
        end
      end
    end

    def self.output_setup(opts={})
      prefix = opts[:prefix]
      Writer.new prefix
    end
  end
end
