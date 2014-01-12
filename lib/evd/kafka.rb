require 'thread'
require 'poseidon'

module EVD
  module Kafka
    MessageToSend = Poseidon::MessageToSend

    # A Kafka producer proxy for Poseidon (a kafka library) that delegates all
    # blocking work to the EventMachine thread pool.
    class Producer
      class Request
        include EM::Deferrable
      end

      def initialize(*args)
        @args = args
        @mutex = Mutex.new
      end

      def send_messages(messages)
        execute do |p|
          p.send_messages messages
        end
      end

      private

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
        unless block_given?
          raise "Expected block"
        end

        request = Request.new

        EM.defer do
          begin
            result = block.call(make_producer)
            EM.next_tick{request.succeed(result)}
          rescue => e
            EM.next_tick{request.fail(e)}
          end
        end

        request
      end
    end
  end
end
