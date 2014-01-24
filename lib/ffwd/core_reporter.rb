module FFWD
  class CoreReporter
    def initialize reporters
      @reporters = reporters
    end

    def collect
      @reporters.each do |reporter|
        reporter.report do |key, value|
          yield key, value
        end
      end
    end
  end
end
