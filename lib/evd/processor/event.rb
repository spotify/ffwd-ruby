require 'evd/event'
require 'evd/processor'
require 'evd/logging'

module EVD::Processor
  #
  # Implements counting statistics (similar to statsd).
  #
  class EventProcessor
    include EVD::Logging
    include EVD::Processor

    register_type "event"

    DEFAULT_TTL = 300

    def initialize(opts={})
      @ttl = opts[:ttl] || DEFAULT_TTL
    end

    def process(core, m)
      m[:ttl] ||= @ttl
      m[:source] = m[:key]
      core.emit m
    end
  end
end
