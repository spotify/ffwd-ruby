module EVD::Plugin
  module Kafka
    module Zookeeper
      class ListBrokers
        include EM::Deferrable

        def initialize(zk)
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

            requests = EVD::EMExt::All.new

            ids.each do |id|
              requests << zk.get(:path => "/brokers/ids/0")
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
              fail nil
            end
          end

          list.errback do |e|
            fail e
          end

          self
        end
      end

      class FindBroker
        include EM::Deferrable

        def initialize(zk)
          request zk
        end

        private

        def request(zk)
          list = ListBrokers.new(zk)

          list.callback do |brokers|
            if brokers.empty?
              fail RuntimeError.new("No brokers registered")
              return
            end

            succeed brokers.first
          end

          list.errback do |e|
            fail e
          end
        end
      end

      def zk_list_brokers zk
        ListBrokers.new(zk)
      end

      def zk_find_broker zk
        FindBroker.new(zk)
      end
    end
  end
end
