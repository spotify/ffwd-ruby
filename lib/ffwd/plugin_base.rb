module FFWD
  class PluginBase
    def self.new *args
      allocate.instance_eval do
        @stopping = []
        initialize(*args)
        self
      end
    end

    def start *args
      init(*args)
    end

    def stop
      @stopping.each do |p|
        p.call
      end
    end

    def stopping &block
      @stopping << block
    end

    def init *args
      raise "not implemented: init"
    end
  end
end
