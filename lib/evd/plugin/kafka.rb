require 'evd/plugin'
require 'evd/logging'
require 'evd/zookeeper'
require 'evd/em_ext'

module EVD::Plugin
  module Kafka
    include EVD::Plugin
    include EVD::Logging

    register_plugin "kafka"

    class BrokersList
      include EM::Deferrable

      def initialize(zk)
        @zk = zk
      end

      def request
        list = @zk.get_children(:path => '/brokers/ids')

        list.callback do |result|
          ids = result[:children]

          if ids.empty?
            log.error "Unable to discover any brokers"
            return
          end

          requests = EVD::EMExt::All.new

          ids.each do |id|
            requests << @zk.get(:path => "/brokers/ids/0")
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

    class Client
      include EVD::Logging

      def initialize(zk_url)
        @zk = EVD::Zookeeper.new(zk_url) unless zk_url.nil?
      end

      def start(channel)
        if @zk
          req = BrokersList.new(@zk).request

          req.callback do |brokers|
            if brokers.empty?
              log.error "Empty list of brokers..."
              return
            end

            log.info "Brokers: #{brokers}"
          end

          req.errback do
            log.error "Failed to request brokers"
          end
        end
      end
    end

    DEFAULT_URL = "localhost:2181"

    def self.output_setup(opts={})
      zk_url = opts[:zk_url] || DEFAULT_URL
      Client.new zk_url
    end
  end
end
