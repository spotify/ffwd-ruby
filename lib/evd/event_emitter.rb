require_relative 'logging'
require_relative 'utils'
require_relative 'event'

module EVD
  class EventEmitter
    def initialize output, base, opts
      @output = output
      @host = opts[:host] || base[:host] || EVD.current_host
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
