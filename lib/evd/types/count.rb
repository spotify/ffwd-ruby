require 'evd/data_type'

module EVD
  class Count < DataType
    register_type "count"

    def op_add(a, b)
      a + b
    end

    def op_sub(a, b)
      a - b
    end

    def initialize(app)
      @app = app
      @cache = {}
      @operations = {
        "sub" => method(:op_sub),
        "add" => method(:op_add),
      }
    end

    def process(msg)
      key = msg["key"]
      return unless key

      op = msg["$op"]
      return unless op

      oper = @operations[op]
      return unless oper

      value = msg["value"] || 0

      old = @cache[key]

      unless old.nil?
        value = oper.call(old, value)
        @app.emit(:key => key, :value => value)
      end

      @cache[key] = value
    end
  end
end
