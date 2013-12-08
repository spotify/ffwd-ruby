require 'evd/processor'
require 'evd/logging'

module EVD::Processor
  #
  # Implements gauge statistics (similar to statsd).
  #
  # A gauge is simply an absolute value which will immediately be updated.
  #
  class GaugeProcessor
    include EVD::Logging
    include EVD::Processor

    register_type "gauge"

    DEFAULT_MISSING = 0

    def initialize(opts={})
      @missing = opts[:missing] || DEFAULT_MISSING
    end

    def process(m)
      m[:value] ||= @missing
      m[:source] = m[:key]
      emit m
    end
  end
end
