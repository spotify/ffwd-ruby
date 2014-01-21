module EVD::Reporter
  module ClassMethods
    def reporter_keys
      @keys ||= [:total]
    end

    def set_reporter_keys *keys
      @keys = [:total] + keys
    end
  end

  def self.included mod
    mod.extend ClassMethods
  end

  def report_data
    @report_data ||= Hash[self.class.reporter_keys.map do |k|
      [k, 0]
    end]
  end

  def id
    self.class.name
  end

  def increment n, c
    report_data[n] += c
    report_data[:total] += c
  end

  def report
    report_data.each do |k, v|
      yield "#{id} #{k}", v
      report_data[k] = 0
    end
  end
end
