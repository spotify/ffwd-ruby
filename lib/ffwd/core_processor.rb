require_relative 'event_emitter'
require_relative 'lifecycle'

module FFWD
  # Component responsible for receiving and internally route metrics and
  # events.
  #
  # The term 'processor' is used because depending on the set of provided
  # processors it might be determined that the received metric should be
  # provided to one of them instead.
  #
  # If no processor matches, it is just passed straight through.
  class CoreProcessor
    def self.build input, emitter, processors
      processors = Hash[processors.map{|p| [p.name, p.setup(emitter)]}]
      reporters = processors.select{|k, p| FFWD.is_reporter?(p)}.map{|k, p| p}
      new(input, emitter, processors, reporters)
    end

    def initialize input, emitter, processors, reporters
      @emitter = emitter
      @processors = processors
      @reporters = reporters

      subs = []

      @processors.each do |name, p|
        p.depend_on input
      end

      input.starting do
        subs << input.metric_subscribe do |m|
          process_metric m
        end

        subs << input.event_subscribe do |e|
          process_event e
        end
      end

      input.stopping do
        subs.each(&:unsubscribe).clear
      end
    end

    def report!
      @reporters.each do |reporter|
        reporter.report! do |d|
          yield d
        end
      end
    end

    private

    def process_metric m
      m[:time] ||= Time.now

      unless p = m[:proc]
        return @emitter.metric.emit m
      end

      unless p = @processors[p]
        return @emitter.metric.emit m
      end

      p.process m
    end

    def process_event e
      e[:time] ||= Time.now
      @emitter.event.emit e
    end
  end
end
