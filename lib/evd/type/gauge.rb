require 'evd/logging'
require 'evd/data_type'

module EVD::Type
  #
  # Implements gauge statistics (similar to statsd).
  #
  # A gauge is simply an absolute value which will immediately be updated.
  #
  class Gauge
    include EVD::Logging
    include EVD::DataType

    register_type "gauge"

    DEFAULT_MISSING = 0

    def initialize(opts={})
      @missing = opts[:missing] || DEFAULT_MISSING
    end

    def process(m)
      emit m.merge(:value => m[:value] || @missing, :source => m[:key])
    end
  end
end
