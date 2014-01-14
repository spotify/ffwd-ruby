require_relative 'event_emitter'

module EVD
  class CoreProcessor
    attr_reader :reporters

    def initialize emitter, processors
      @emitter = emitter
      @processors = setup_processors processors
      @reporters = EVD.setup_reporters @processors
    end

    def setup_processors processors
      processors = Hash[processors.map do |k, p|
        [k, p.call]
      end]

      processors.each do |k, p|
        next unless p.respond_to?(:start)
        p.start @emitter
      end

      return processors
    end

    def process_metric m
      m[:time] ||= Time.now

      unless p = m[:proc]
        return @emitter.emit_metric m
      end

      unless p = @processors[p]
        return @emitter.emit_metric m
      end

      emitter = if m[:tags] or m[:attributes]
        EventEmitter.new @emitter, m[:tags], m[:attributes]
      else
        @emitter
      end

      p.process emitter, m
    end

    def process_event e
      e[:time] ||= Time.now
      @emitter.emit_event e
    end
  end
end
