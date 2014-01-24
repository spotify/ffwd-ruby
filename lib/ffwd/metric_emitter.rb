require_relative 'utils'
require_relative 'metric'

module FFWD
  # Used to emit metrics to an 'output' channel
  #
  # Can take two parts of a configuration 'base' and 'opts' to decide which
  # metadata emitted metrics should be decorated with.
  class MetricEmitter
    def initialize output, base, opts
      @output = output
      @host = opts[:host] || base[:host] || FFWD.current_host
      @tags = FFWD.merge_sets base[:tags], opts[:tags]
      @attributes = FFWD.merge_hashes base[:attributes], opts[:attributes]
    end

    def emit m
      m[:time] ||= Time.now
      m[:host] ||= @host if @host
      m[:tags] = FFWD.merge_sets @tags, m[:tags]
      m[:attributes] = FFWD.merge_hashes @attributes, m[:attributes]

      @output.metric FFWD.metric(m)
    end
  end
end
