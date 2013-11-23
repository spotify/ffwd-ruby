require 'evd/data_type'

module EVD
  #
  # Implements derive statistics (similar to collectd).
  #
  class Derive
    include EVD::DataType

    register_type "derive"

    def initialize
      @cache = {}
    end

    def process(msg)
      key = msg[:key]
      current_time = msg[:time]
      current_value = msg[:value] || 0

      prev = @cache[key]

      if prev
        prev_time = prev[:time]
        prev_value = prev[:value]

        difference = (current_time - prev_time)

        if difference > 0
          rate = (current_value - prev_value) / difference
          emit(:key => key, :value => rate)
        end
      end

      @cache[key] = msg
    end
  end
end
