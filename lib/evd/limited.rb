# Defines containers which are limited in size.
module EVD::Limited
  class Queue
    def initialize(name, log, limit)
      @name = name
      @log = log
      @limit = limit
      @queue = EventMachine::Queue.new
    end

    def <<(item)
      if @queue.size >= @limit
        @log.warning "#{@name}: Queue limit of #{@limit} reached, item dropped"
        return
      end

      @queue << item
    end

    def pop(&block)
      @queue.pop block
    end
  end
end
