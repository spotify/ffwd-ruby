require 'evd/logging'
require 'evd/reporter'

module EVD
  # A client implementation that delegates all work to other threads.
  class ProducingClient
    include EVD::Logging
    include EVD::Reporter

    def initialize(flush_period, flush_size, buffer_limit)
      @flush_period = flush_period
      @flush_size = flush_size
      @buffer_limit = buffer_limit
      @buffer = []
      @kafka_producer = nil
      @send_request = nil
    end

    def start(channel)
      setup_producer

      EM::PeriodicTimer.new(@flush_period){flush!}

      channel.subscribe do |e|
        return increment :dropped, 1 if @buffer.size >= @buffer_limit
        @buffer << e
        flush! if @buffer.size >= @flush_size
      end
    end

    protected

    def produce(buffer); raise "Not implemented: produce"; end
    def setup_producer; raise "Not implemented: setup_producer"; end

    private

    def flush!
      return increment :dropped, @buffer.size unless @kafka_producer
      return increment :dropped, @buffer.size if @send_request

      @send_request = produce @buffer

      size = @buffer.size

      @send_request.callback do
        increment :sent, size
        @buffer.clear
        @send_request = nil
      end

      @send_request.errback do
        increment :failed, size
        @buffer.clear
        @send_request = nil
      end
    rescue => e
      increment :failed, @buffer.size
      log.error "Failed to flush messages", e
    ensure
      @buffer.clear
    end
  end
end
