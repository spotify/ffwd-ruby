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

  def report prefix
    lines = []

    @report_data = Hash[report_data.map do |k, v|
      lines << "#{k}=#{v}" if v > 0
      [k, 0]
    end]

    log.info "##{prefix} '#{id}': #{lines.join(', ')}"
  end
end
