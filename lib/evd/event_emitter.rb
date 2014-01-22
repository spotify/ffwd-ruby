require_relative 'utils'
require_relative 'event'

module EVD
  # Used to emit events to an 'output' channel
  #
  # Can take two parts of a configuration 'base' and 'opts' to decide which
  # metadata emitted events should be decorated with.
  class EventEmitter
    def initialize output, base, opts
      @output = output
      @host = opts[:host] || base[:host] || EVD.current_host
      @ttl = opts[:ttl] || base[:ttl]
      @tags = EVD.merge_sets base[:tags], opts[:tags]
      @attributes = EVD.merge_hashes base[:attributes], opts[:attributes]
    end

    def emit e
      e[:time] ||= Time.now
      e[:host] ||= @host if @host
      e[:ttl] ||= @ttl if @ttl
      e[:tags] = EVD.merge_sets @tags, e[:tags]
      e[:attributes] = EVD.merge_hashes @attributes, e[:attributes]

      @output.event EVD.event(e)
    end
  end
end
