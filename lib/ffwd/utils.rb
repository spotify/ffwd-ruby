require 'socket'
require 'set'

module FFWD
  # Merge two sets (arrays actually)
  def self.merge_sets(a, b)
    return Set.new(a + b).to_a if a and b
    a || b || []
  end

  # Merge two hashes.
  def self.merge_hashes(a, b)
    return a.merge(b) if a and b
    b || a || {}
  end

  def self.is_reporter? var
    var.respond_to? :report!
  end

  def self.current_host
    Socket.gethostname
  end

  def self.timing &block
    start = Time.now
    block.call
    stop = Time.now
    ((stop - start) * 1000).round(3)
  end
end
