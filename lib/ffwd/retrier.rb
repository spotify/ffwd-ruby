require_relative 'logging'

module FFWD
  # Try to execute a block on an exponential timer until it no longer throws
  # an exception.
  class Retrier
    attr_reader :log

    def initialize log, lifecycle, retry_timeout, &block
      @log = log
      @block = block
      @timer = nil
      @retry_timeout = retry_timeout
      @current_timeout = @retry_timeout
      @attempt = 0
      @error_callbacks = []

      lifecycle.starting do
        try_block
      end

      lifecycle.stopping do
        if @timer
          @timer.cancel
          @timer = nil
        end
      end
    end

    def error &block
      @error_callbacks << block
    end

    def try_block
      @attempt += 1
      @block.call @attempt
    rescue => e
      @error_callbacks.each do |block|
        begin
          block.call @attempt, @current_timeout, e
        rescue => e
          log.error "Failed to call error block", e
        end
      end

      @timer = EM::Timer.new(@current_timeout) do
        @current_timeout *= 2
        @timer = nil
        try_block
      end
    end
  end
end
