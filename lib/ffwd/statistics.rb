require_relative 'lifecycle'
require_relative 'logging'

require_relative 'statistics/collector'

module FFWD
  module Statistics
    include FFWD::Logging

    def self.setup emitter, channel, opts={}
      Collector.new log, emitter, channel, opts
    end
  end
end
