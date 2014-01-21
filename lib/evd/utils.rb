require 'socket'

module EVD
  # Merge two sets (arrays actually)
  def self.merge_sets(a, b)
    return a + b if a and b
    a || b || []
  end

  # Merge two hashes.
  def self.merge_hashes(a, b)
    return a.merge(b) if a and b
    b || a || {}
  end

  def self.is_reporter? var
    var.respond_to? :report and var.respond_to? :report?
  end

  def self.current_host
    Socket.gethostname
  end
end
