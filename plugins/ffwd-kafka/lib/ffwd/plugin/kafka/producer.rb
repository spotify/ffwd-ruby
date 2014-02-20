require 'poseidon'

module FFWD::Plugin::Kafka
  MessageToSend = Poseidon::MessageToSend

  # A Kafka producer proxy for Poseidon (a kafka library) that delegates all
  # blocking work to the EventMachine thread pool.
  class Producer
    class Request
      include EM::Deferrable
    end

    def initialize *args
      @args = args
      @mutex = Mutex.new
      @request = nil
      @stopped = false
    end

    def stop
      @stopped = true
      shutdown
    end

    def shutdown
      return if @request

      @mutex.synchronize do
        @producer.shutdown
      end
    end

    def send_messages messages
      execute do |p|
        p.send_messages messages
      end
    end

    def make_producer
      if EM.reactor_thread?
        raise "Should not be called in the reactor thread"
      end

      @mutex.synchronize do
        @producer ||= Poseidon::Producer.new(*@args)
      end
    end

    # Execute the provided block on a dedicated thread.
    # The sole provided argument is an instance of Poseidon::Producer.
    def execute &block
      raise "Expected block" unless block_given?
      raise "Request already pending" if @request

      if @stopped
        r = Request.new
        r.fail "producer stopped"
        return r
      end

      @request = Request.new

      EM.defer do
        begin
          result = block.call make_producer

          EM.next_tick do
            @request.succeed result
            @request = nil
            shutdown if @stopped
          end
        rescue => e
          EM.next_tick do
            @request.fail e
            @request = nil
            shutdown if @stopped
          end
        end
      end

      @request
    end
  end
end
