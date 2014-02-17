require_relative '../logging'
require_relative '../utils'
require_relative '../metric_emitter'
require_relative '../event_emitter'

module FFWD
  class Core; end

  class Core::Emitter
    attr_reader :event, :metric

    def self.build output, opts={}
      event = EventEmitter.build output, opts, opts[:event] || {}
      metric = MetricEmitter.build output, opts, opts[:metric] || {}
      new(event, metric)
    end

    def initialize event, metric
      @event = event
      @metric = metric
    end
  end
end
