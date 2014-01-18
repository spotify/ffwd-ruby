require 'socket'

module EVD
  # Merge two sets
  def self.merge_sets(a, b)
    return a + b if a and b
    a || b || []
  end

  # Merge two hashes.
  def self.merge_hashes(a, b)
    return b if not a
    r = a.clone
    r.update(b) if b
  end

  def self.setup_reporters instances
    reporters = []

    instances.each do |i|
      next unless i.respond_to? :report and i.respond_to? :report?
      reporters << i
    end

    reporters
  end

  def self.current_host
    Socket.gethostname
  end
end
