require 'evd/output_plugin'
require 'evd/logging'

module EVD
  class OutputLog < OutputPlugin
    include EVD::Logging

    register_output "log"

    def initialize(opts={})
      @prefix = opts[:prefix] || "(no prefix)"
    end

    def setup(buffer)
      process_events buffer
    end

    def process_events(buffer)
      buffer.pop do |event|
        process event
        process_events buffer
      end
    end

    def process(event)
      log.info "#{@prefix}: Output: #{event}"
    end
  end
end
