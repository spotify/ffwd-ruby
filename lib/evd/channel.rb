# Defines containers which are limited in size.
module EVD
  class Channel
    def initialize(log, name)
      @log = log
      @name = name
      @subs = []
    end

    def <<(item)
      @subs.each do |s|
        begin
          s.call item
        rescue => e
          @log.error "#{@name}: Subscription failed: #{e}"
          @log.error e.backtrace.join('\n')
        end
      end
    end

    def subscribe(&cb)
      @subs << cb
    end
  end
end
