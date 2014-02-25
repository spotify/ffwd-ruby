# $LICENSE
# Copyright 2013-2014 Spotify AB. All rights reserved.
#
# The contents of this file are licensed under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with the
# License. You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

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
