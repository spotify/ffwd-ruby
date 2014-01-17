require 'set'

# Defines containers which are limited in size.
module EVD
  class Channel
    def initialize(log, name)
      @log = log
      @name = name
      @subs = Set.new
    end

    def <<(item)
      @subs.each do |s|
        begin
          s.call item
        rescue => e
          @log.error "#{@name}: Subscription failed", e
        end
      end
    end

    def subscribe(&cb)
      @subs << cb
      return cb
    end

    def unsubscribe cb
      @subs.delete cb
    end
  end
end
