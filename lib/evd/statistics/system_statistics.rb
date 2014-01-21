require_relative '../logging'

module EVD::Statistics
  # Example SMAP
  #(mapping header)
  #Size:                  4 kB
  #Rss:                   0 kB
  #Pss:                   0 kB
  #Shared_Clean:          0 kB
  #Shared_Dirty:          0 kB
  #Private_Clean:         0 kB
  #Private_Dirty:         0 kB
  #Referenced:            0 kB
  #Anonymous:             0 kB
  #AnonHugePages:         0 kB
  #Swap:                  0 kB
  #KernelPageSize:        4 kB
  #MMUPageSize:           4 kB
  #Locked:                0 kB
  #VmFlags: rd ex 

  class SMAP
    attr_reader :size
    attr_reader :rss
    attr_reader :pss
    attr_reader :shared_clean
    attr_reader :shared_dirty
    attr_reader :private_clean
    attr_reader :private_dirty
    attr_reader :referenced
    attr_reader :anonymous
    attr_reader :anon_huge_pages
    attr_reader :swap
    attr_reader :kernel_page_size
    attr_reader :mmu_page_size
    attr_reader :locked
    attr_reader :vmflags

    KEY_MAPPING = {
      "Size" => :size,
      "Rss" => :rss,
      "Pss" => :pss,
      "Shared_Clean" => :shared_clean,
      "Shared_Dirty" => :shared_dirty,
      "Private_Clean" => :private_clean,
      "Private_Dirty" => :private_dirty,
      "Referenced" => :referenced,
      "Anonymous" => :anonymous,
      "AnonHugePages" => :anon_huge_pages,
      "Swap" => :swap,
      "KernelPageSize" => :kernel_page_size,
      "MMUPageSize" => :mmu_page_size,
      "Locked" => :locked,
      "VmFlags" => :vm_flags,
    }

    TYPE_MAP = {
      "VmFlags" => lambda{|s| s}
    }

    DEFAULT_TYPE = lambda{|s| s[0, s.size - 3].to_i * 1024}

    def initialize values
      values.each do |key, value|
        unless target = KEY_MAPPING[key]
          raise "unexpected key: #{key}"
        end

        instance_variable_set "@#{target}", value
      end
    end
  end

  class SystemStatistics
    include EVD::Logging

    SMAPS_FILE = '/proc/self/smaps'

    def initialize system_channel, opts={}
      @system_channel = system_channel
    end

    def collect
      memory_use = memory_usage

      memory_use.each do |key, value|
        yield "statistics-system/#{key}", value
      end

      if @system_channel
        @system_channel << memory_use
      end
    end

    def check
      if not File.file? SMAPS_FILE
        log.error "file does not exist: #{SMAPS_FILE} (is this a linux system?)"
        return false
      end

      return true
    end

    def memory_usage
      result = {:rss => 0, :pss => 0}

      read_smaps do |smap|
        result[:rss] += smap.rss
        result[:pss] += smap.pss
      end

      result
    end

    private

    def read_smaps
      File.open(SMAPS_FILE) do |f|
        smap = {}

        loop do
          break if f.eof?

          unless smap.empty?
            yield SMAP.new(smap)
            smap = {}
          end

          loop do
            break if f.eof?

            line = f.readline.strip

            case line
            when /^[0-9a-f]+-[0-9a-f]+ /
              break
            else
              key, value = line.split(':', 2)
              next unless SMAP::KEY_MAPPING[key]
              smap[key] = (SMAP::TYPE_MAP[key] || SMAP::DEFAULT_TYPE).call(value.strip)
            end
          end
        end
      end
    end

    def smaps_read_entry f
      result = {}

      loop do
        break if f.eof?

        line = f.readline.strip

        case line
        when /^[0-9a-f]+-[0-9a-f]+ /
          break
        else
          result[key] = (SMAP::TYPE_MAP[key] || SMAP::DEFAULT_TYPE).call(value.strip)
        end
      end

      result
    end
  end
end
