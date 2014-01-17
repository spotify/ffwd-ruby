require_relative 'utils'

module EVD
  class EventEmitter
    def initialize core, tags, attributes
      @core = core
      @tags = tags
      @attributes = attributes
    end

    def emit_event e
      e[:tags] = EVD.merge_sets @tags, e[:tags]
      e[:attributes] = EVD.merge_hashes @attributes, e[:attributes]
      @core.emit_event e
    end

    def emit_metric m
      @core.emit_metric m
    end
  end
end
