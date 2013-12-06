# Defines containers which are limited in size.
module EVD::Limited
  class Channel
    def initialize(name, log, limit)
      @name = name
      @log = log
      @limit = limit
      @items = []
      @cb = nil
    end

    def <<(item)
      if @items.size >= @limit
        @log.warning "#{@name}: Channel limit of #{@limit} reached, item dropped"
        return
      end

      if @cb.nil?
        @items.push item
      else
        cb = @cb
        EM.next_tick{cb.call item}
        @cb = nil
      end
    end

    def pop(&cb)
      raise "Only one consumer can pop at a time" unless @cb.nil?

      if @items.empty?
        @cb = cb
      else
        item = @items.shift
        EM.next_tick{cb.call item}
      end
    end
  end
end
