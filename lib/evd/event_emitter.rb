require_relative 'utils'

module EVD
  class EventEmitter
    def initialize core, tags, attributes
      @core = core
      @tags = tags
      @attributes = attributes
    end

    def emit_event e, tags=nil, attributes=nil
      tags = EVD.merge_sets tags, @tags
      attributes = EVD.merge_hashes attributes, @attributes
      @core.emit_event e, tags, attributes
    end

    def emit_metric m
      @core.emit_metric m
    end
  end
end
