require 'zookeeper'
require 'thread'

module FFWD
  # A tiny zookeeper wrapper that delegates requests to the thread-pool of
  # EventMachine.
  class ZookeeperClient
    class Request
      include EM::Deferrable
    end

    def initialize(*args)
      @args = args
      @mutex = Mutex.new
    end

    def get_children(*args)
      execute do |c|
        c.get_children(*args)
      end
    end

    def get(*args)
      execute do |c|
        c.get(*args)
      end
    end

    private

    # Setup the shared zookeeper connection in a mutex, because multiple
    # threads could access it at once.
    # NOTE: It is important that ::Zookeeper is not instantiated on the reactor
    # thread, because it blocks if it is unable to establish a connection.
    def make_client
      raise "Should not be used in the reactor thread" if EM.reactor_thread?

      @mutex.synchronize do
        @client ||= ::Zookeeper.new(*@args)
      end

      return @client
    end

    def execute(&block)
      request = Request.new

      EM.defer do
        begin
          result = block.call(make_client)
          EM.next_tick{request.succeed(result)}
        rescue => e
          EM.next_tick{request.fail(e)}
        end
      end

      return request
    end
  end
end
