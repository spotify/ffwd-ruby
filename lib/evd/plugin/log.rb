require_relative '../event'
require_relative '../metric'
require_relative '../plugin'
require_relative '../logging'

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
        channel.event_subscribe do |e|
          log.info "Event: #{@p}#{EVD.event_to_h e}"
        end

        channel.metric_subscribe do |m|
          log.info "Metric: #{@p}#{EVD.metric_to_h m}"
        end
      end
    end

    def self.output_setup(opts={})
      prefix = opts[:prefix]
      Writer.new prefix
    end
  end
end
