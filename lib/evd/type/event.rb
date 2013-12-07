require 'evd/logging'
require 'evd/data_type'

module EVD::Type
  #
  # Implements counting statistics (similar to statsd).
  #
  class Event
    include EVD::Logging
    include EVD::DataType

    register_type "event"

    DEFAULT_TTL = 300

    def initialize(opts={})
      @ttl = opts[:ttl] || DEFAULT_TTL
    end

    def process(m)
      emit m.merge(:ttl => m[:ttl] || @ttl, :source => m[:key])
    end
  end
end
