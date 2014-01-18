require_relative 'event_emitter'

module EVD
  class CoreProcessor
    attr_reader :reporters

    def initialize emitter, processors
      @emitter = emitter
      @processors = Hash[processors.map{|k, p| [k, p.call(@emitter)]}]
      @reporters = EVD.setup_reporters @processors
    end

    def start input
      @processors.each do |name, p|
        p.start
      end

      input.metric_subscribe do |m|
        process_metric m
      end

      input.event_subscribe do |e|
        process_event e
      end
    end

    def stop
      @processors.each do |name, p|
        p.stop
      end
    end

    private

    def process_metric m
      m[:time] ||= Time.now

      unless p = m[:proc]
        return @emitter.emit_metric m
      end

      unless p = @processors[p]
        return @emitter.emit_metric m
      end

      p.process m
    end

    def process_event e
      e[:time] ||= Time.now
      @emitter.emit_event e
    end
  end
end
