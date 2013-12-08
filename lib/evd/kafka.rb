require 'thread'
require 'poseidon'

module EVD
  class Kafka
    MessageToSend = Poseidon::MessageToSend

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
        raise "Should not be used in the reactor thread" if EM.reactor_thread?

        @mutex.synchronize do
          @producer ||= Poseidon::Producer.new(*@args)
        end
      end

      def execute(&block)
        request = Request.new

        EM.defer do
          begin
            result = block.call(make_producer)
            EM.next_tick{request.succeed(result)}
          rescue => e
            EM.next_tick{request.fail(e)}
          end
        end

        return request
      end
    end

    def initialize
      @client_mutex = Mutex.new
    end

    def producer(*args)
      Producer.new(*args)
    end
  end
end
