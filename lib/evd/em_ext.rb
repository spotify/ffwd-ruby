module EVD::EMExt
  class All
    include EM::Deferrable

    def initialize
      @defs = []
      @errors = []
      @results = []
      @all_ok = true
      @any_ok = false
      @done = 0
    end

    def <<(d)
      @defs << d

      index = @results.size

      @results << nil
      @errors << nil

      d.callback do |*args|
        @results[index] = args
        @any_ok = true
        check_results
      end

      d.errback do |*args|
        @errors[index] = args
        @all_ok = false
        check_results
      end
    end

    private

    def check_results
      @done += 1

      return unless @defs.size == @done

      unless @all_ok
        fail(@errors)
        return
      end

      succeed(@results)
    end
  end
end
