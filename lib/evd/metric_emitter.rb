require_relative 'logging'
require_relative 'utils'
require_relative 'metric'

module EVD
  class MetricEmitter
    include EVD::Logging

    def initialize output, base, opts
      @output = output
      @host = opts[:host] || base[:host] || EVD.current_host
      @tags = EVD.merge_sets base[:tags], opts[:tags]
      @attributes = EVD.merge_hashes base[:attributes], opts[:attributes]
    end

    def emit m
      m[:time] ||= Time.now
      m[:host] ||= @host if @host
      m[:tags] = EVD.merge_sets @tags, m[:tags]
      m[:attributes] = EVD.merge_hashes @attributes, m[:attributes]

      @output.metric EVD.metric(m)
    end
  end
end
