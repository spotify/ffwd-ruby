require 'set'

module EVD
  # Merge two sets
  def self.merge_sets(a, b)
    return b if not a
    r = a.clone
    r += b if b
  end

  # Merge two hashes.
  def self.merge_hashes(a, b)
    return b if not a
    r = a.clone
    r.update(b) if b
  end
end
