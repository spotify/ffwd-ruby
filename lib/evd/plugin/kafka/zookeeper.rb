require 'em/all'

module EVD::Plugin
  module Kafka
    module Zookeeper
      class FindBrokers
        include EM::Deferrable

        def initialize(log, zk)
          @log = log
          request zk
        end

        private

        def request(zk)
          list = zk.get_children(:path => '/brokers/ids')

          list.callback do |result|
            ids = result[:children]

            if ids.empty?
              log.error "Unable to discover any brokers"
              return
            end

            requests = EM::All.new

            ids.each do |id|
              requests << zk.get(:path => "/brokers/ids/#{id}")
            end

            requests.callback do |result_brokers|
              brokers = []

              result_brokers.each do |result_broker|
                broker = JSON.load(result_broker[0][:data])
                next if broker.nil?
                brokers << {:host => broker["host"], :port => broker["port"]}
              end

              succeed brokers
            end

            requests.errback do |errors|
              errors.each do |e|
                next unless e
                @log.error "Failed to request broker information", e
              end

              fail nil
            end
          end

          list.errback do |e|
            fail e
          end
        end
      end

      def zk_find_brokers(log, zk)
        FindBrokers.new(log, zk)
      end
    end
  end
end
