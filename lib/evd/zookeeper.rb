require 'zookeeper'

module EVD
  class Request
    include EM::Deferrable
  end

  # A tiny zookeeper wrapper that delegates requests to the thread-pool of
  # EventMachine.
  class Zookeeper
    def initialize(*args)
      @zk = ::Zookeeper.new(*args)
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

    def execute(&block)
      request = Request.new

      EM.defer do
        begin
          result = block.call(@zk)
          EM.next_tick{request.succeed(result)}
        rescue => e
          EM.next_tick{request.fail(e)}
        end
      end

      return request
    end
  end
end
