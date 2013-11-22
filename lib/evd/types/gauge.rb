require 'evd/data_type'

module EVD
  class Gauge < DataType
    register_type "gauge"

    def process(msg)
      key = msg["key"]
      return unless key
      value = msg["value"] || 0
      emit(:key => key, :value => rate)
    end
  end
end
