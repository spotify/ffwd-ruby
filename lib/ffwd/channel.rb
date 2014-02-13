require 'set'

# Defines containers which are limited in size.
module FFWD
  class Channel
    class Sub
      attr_reader :channel, :block

      def initialize channel, block
        @channel = channel
        @block = block
      end

      def unsubscribe
        @channel.unsubscribe self
      end
    end

    attr_reader :subs

    def initialize log, name
      @log = log
      @name = name
      @subs = Set.new
    end

    def <<(item)
      @subs.each do |sub|
        begin
          sub.block.call item
        rescue => e
          @log.error "#{@name}: Subscription failed", e
        end
      end
    end

    def subscribe(&block)
      s = Sub.new(self, block)
      @subs << s
      return s
    end

    def unsubscribe sub
      @subs.delete sub
    end
  end
end
