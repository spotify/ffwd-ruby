require 'evd/logging'

module EVD
  class UpdateHash
    include EVD::Logging

    def initialize(base, target, limit, oper)
      @base = base
      @target = target
      @limit = limit
      @oper = oper
    end

    def process(msg)
      return if (key = msg[:key]).nil?

      if @target[key].nil? and @target.size >= @limit
        log.warning "Dropping metadata update for '#{key}', limit reached"
        return
      end

      if (value = msg[:value]).nil?
        @target.delete key
        return
      end

      @target[key] = @oper.call(@base, value)
    end
  end
end
