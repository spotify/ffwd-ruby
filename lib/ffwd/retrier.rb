require_relative 'logging'
require_relative 'lifecycle'

module FFWD
  # Try to execute a block on an exponential timer until it no longer throws
  # an exception.
  class Retrier
    include FFWD::Lifecycle

    def initialize timeout, &block
      @block = block
      @timer = nil
      @timeout = timeout
      @current_timeout = @timeout
      @attempt = 0
      @error_callbacks = []

      starting do
        try_block
      end

      stopping do
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
      @current_timeout = @timeout
    rescue => e
      @error_callbacks.each do |block|
        block.call @attempt, @current_timeout, e
      end

      @timer = EM::Timer.new(@current_timeout) do
        @current_timeout *= 2
        @timer = nil
        try_block
      end
    end
  end

  DEFAULT_TIMEOUT = 10

  def self.retry opts={}, &block
    timeout = opts[:timeout] || DEFAULT_TIMEOUT
    Retrier.new(timeout, &block)
  end
end
