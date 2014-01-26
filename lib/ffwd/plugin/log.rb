require 'ffwd/event'
require 'ffwd/logging'
require 'ffwd/metric'
require 'ffwd/plugin'
require 'ffwd/plugin_base'

module FFWD::Plugin
  module Log
    include FFWD::Plugin
    include FFWD::Logging

    register_plugin "log"

    class Writer < FFWD::PluginBase
      include FFWD::Logging

      def initialize prefix
        @p = if prefix
          "#{prefix} "
        else
          ""
        end
      end

      def init output
        event_sub = output.event_subscribe do |e|
          log.info "Event: #{@p}#{e.to_h}"
        end

        metric_sub = output.metric_subscribe do |m|
          log.info "Metric: #{@p}#{m.to_h}"
        end

        stopping do
          output.event_unsubscribe event_sub
          output.metric_unsubscribe metric_sub
        end
      end
    end

    def self.setup_output core, opts={}
      prefix = opts[:prefix]
      Writer.new prefix
    end
  end
end
