Node = Struct.new(:value, :next)

module FFWD
  class CircularBuffer
    attr_reader :buffer, :capacity, :size

    def initialize capacity
      @capacity = capacity
      @first = nil
      @last = nil
      @size = 0
    end

    def clear
      @first = nil
      @last = nil
      @size = 0
    end

    def empty?
      size == 0
    end

    def peek
      return nil if @first.nil?
      @first.value
    end

    def shift
      return nil if @first.nil?
      value = @first.value
      @first = @first.next
      @last = nil if @first.nil?
      @size -= 1
      value
    end

    def << item
      node = Node.new(item, nil)

      if @last.nil?
        @first = @last = node
      else
        @last = @last.next = node
      end

      if @size >= @capacity
        @first = @first.next
      else
        @size += 1
      end
    end

    def each
      current = @first

      while not current.nil?
        yield current.value
        current = current.next
      end
    end
  end
end
