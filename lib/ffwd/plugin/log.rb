require_relative '../event'
require_relative '../metric'
require_relative '../plugin'
require_relative '../logging'

module FFWD::Plugin
  module Log
    include FFWD::Plugin
    include FFWD::Logging

    register_plugin "log"

    class Writer
      include FFWD::Logging

      def initialize(prefix)
        @p = if prefix
          "#{prefix} "
        else
          ""
        end
      end

      def start channel
        channel.event_subscribe do |e|
          log.info "Event: #{@p}#{FFWD.event_to_h e}"
        end

        channel.metric_subscribe do |m|
          log.info "Metric: #{@p}#{FFWD.metric_to_h m}"
        end
      end
    end

    def self.setup_output core, opts={}
      prefix = opts[:prefix]
      Writer.new prefix
    end
  end
end
