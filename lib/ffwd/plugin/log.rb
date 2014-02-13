require 'ffwd/event'
require 'ffwd/logging'
require 'ffwd/metric'
require 'ffwd/plugin'

module FFWD::Plugin
  module Log
    include FFWD::Plugin
    include FFWD::Logging

    register_plugin "log"

    class Writer
      include FFWD::Logging

      def initialize core, prefix
        @p = if prefix
          "#{prefix} "
        else
          ""
        end

        subs = []

        core.output.starting do
          subs << core.output.event_subscribe do |e|
            log.info "Event: #{@p}#{e.to_h}"
          end

          subs << core.output.metric_subscribe do |m|
            log.info "Metric: #{@p}#{m.to_h}"
          end
        end

        core.output.stopping do
          subs.each(&:unsubscribe).clear
        end
      end
    end

    def self.setup_output opts, core
      prefix = opts[:prefix]
      Writer.new core, prefix
    end
  end
end
