# $LICENSE
# Copyright 2013-2014 Spotify AB. All rights reserved.
#
# The contents of this file are licensed under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with the
# License. You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

require_relative '../logging'

module FFWD::Statistics
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
    include FFWD::Logging

    PID_SMAPS_FILE = '/proc/self/smaps'
    PID_STAT_FILE = '/proc/self/stat'
    STAT_FILE = '/proc/stat'
    MEMINFO_FILE = '/proc/meminfo'

    def initialize opts={}
      @cpu_prev = nil
    end

    def collect channel
      memory_use = memory_usage
      cpu_use = cpu_usage

      cpu_use.each do |key, value|
        yield "statistics-cpu/#{key}", value
      end

      memory_use.each do |key, value|
        yield "statistics-memory/#{key}", value
      end

      channel << {
        :cpu => cpu_use,
        :memory => memory_use,
      }
    end

    def check
      if not File.file? PID_SMAPS_FILE
        log.error "File does not exist: #{PID_SMAPS_FILE} (is this a linux system?)"
        return false
      end

      if not File.file? PID_STAT_FILE
        log.error "File does not exist: #{PID_STAT_FILE} (is this a linux system?)"
        return false
      end

      if not File.file? STAT_FILE
        log.error "File does not exist: #{STAT_FILE} (is this a linux system?)"
        return false
      end

      if not File.file? MEMINFO_FILE
        log.error "File does not exist: #{MEMINFO_FILE} (is this a linux system?)"
        return false
      end

      return true
    end

    def memory_usage
      result = {:resident => 0, :total => read_total_memory}

      read_smaps do |smap|
        result[:resident] += smap.rss
      end

      result
    end

    def cpu_usage
      stat = read_pid_stat

      current = {
        :system => stat[:stime],
        :user => stat[:utime],
        :total => read_stat_total
      }

      prev = @cpu_prev

      if @cpu_prev.nil?
        @cpu_prev = prev = current
      else
        @cpu_prev = current
      end

      return {
        :system => current[:system] - prev[:system],
        :user => current[:user] - prev[:user],
        :total => current[:total] - prev[:total],
      }
    end

    private

    def read_pid_stat
      File.open(PID_STAT_FILE) do |f|
        stat = f.readline.split(' ').map(&:strip)
        return {:utime => stat[13].to_i, :stime => stat[14].to_i}
      end
    end

    def read_stat_total
      File.open(STAT_FILE) do |f|
        f.each do |line|
          next unless line.start_with? "cpu "
          stat = line.split(' ').map(&:strip).map(&:to_i)
          return stat.reduce(&:+)
        end
      end
    end

    def read_total_memory
      File.open(MEMINFO_FILE) do |f|
        f.each do |line|
          next unless line.start_with? "MemTotal:"
          total = line.split(' ').map(&:strip)
          return total[1].to_i * 1000
        end
      end
    end

    def read_smaps
      File.open(PID_SMAPS_FILE) do |f|
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
