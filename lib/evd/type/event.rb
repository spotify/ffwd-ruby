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

    def initialize(opts={})
      @ttl = opts[:ttl]
    end

    def process(msg)
      msg[:ttl] = @ttl if (msg[:ttl].nil? and not @ttl.nil?)
      msg[:source_key] = msg[:key]
      emit msg
    end
  end
end
