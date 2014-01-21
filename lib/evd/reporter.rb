module EVD::Reporter
  def report_data
    @report_data ||= {:total => 0}
  end

  def id
    self.class.name
  end

  def increment n, c
    report_data[n] = (report_data[n] || 0) + c
    report_data[:total] += c
  end

  def report?
    not report_data.values.all?(&:zero?)
  end

  def report
    report_data.each do |k, v|
      yield "#{id} #{k}", v
    end

    @report_data = nil
  end
end
