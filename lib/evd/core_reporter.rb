module EVD
  class CoreReporter
    def initialize reporters
      @reporters = reporters
    end

    def collect
      active = []

      @reporters.each do |reporter|
        active << reporter if reporter.report?
      end

      return if active.empty?

      active.each_with_index do |reporter|
        reporter.report do |key, value|
          yield key, value
        end
      end
    end
  end
end
