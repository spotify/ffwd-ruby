require 'evd/data_type'

module EVD
  #
  # Implements gauge statistics (similar to statsd).
  #
  # A gauge is simply an absolute value which will immediately be updated.
  #
  class Gauge
    include EVD::DataType

    register_type "gauge"

    def process(msg)
      key = msg[:key]
      value = msg[:value] || 0
      emit(:key => key, :value => value)
    end
  end
end
