require_relative '../../logging'

module FFWD::Plugin::Log
  class Writer
    include FFWD::Logging

    def initialize core, prefix
      @p = prefix ? "#{prefix} " : ""

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
end
