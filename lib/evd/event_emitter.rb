require 'evd/utils'

module EVD
  class EventEmitter
    def initialize(core, tags, attributes)
      @core = core
      @tags = tags
      @attributes = attributes
    end

    def emit(m, tags=nil, attributes=nil)
      tags = EVD.merge_sets @tags, tags
      attributes = EVD.merge_hashes @attributes, attributes
      @core.emit m, tags, attributes
    end
  end
end
