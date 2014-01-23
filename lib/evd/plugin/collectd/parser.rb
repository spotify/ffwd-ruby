require 'evd/logging'

module EVD::Plugin::Collectd
  # An parser implementation of
  # https://collectd.org/wiki/index.php/Binary_protocol
  module Parser
    include EVD::Logging

    HOST = 0x0000
    TIME = 0x0001
    TIME_HR = 0x0008
    PLUGIN = 0x0002
    PLUGIN_INSTANCE = 0x0003
    TYPE = 0x0004
    TYPE_INSTANCE = 0x0005
    VALUES = 0x0006
    INTERVAL = 0x0007
    INTERVAL_HR = 0x0009
    MESSAGE = 0x0100
    SEVERITY = 0x0101

    COUNTER = 0
    GAUGE = 1
    DERIVE = 2
    ABSOLUTE = 3

    SB64 = 0x8000000000000000
    B64 = 0x10000000000000000

    FACTOR_HR = 2**30

    def self.unsigned_integer data
      high, low = data.unpack("NN")
      ((high << 32) | low)
    end

    def self.signed_integer data
      us = unsigned_integer(data)

      if (us & SB64) == SB64
        us - B64
      else
        us
      end
    end

    def self.values frame, i, size
      n = frame[i + 4, 2].unpack("n")[0]

      result = []

      types = frame[i + 6, n].unpack("C" * n)

      types.each_with_index do |type, j|
        o = 6 + n + (j * 8)
        data = frame[i + o, 8]

        case type
        when COUNTER
          result << [:counter, self.unsigned_integer(data)]
        when GAUGE
          result << [:gauge, data.unpack("E")[0]]
        when DERIVE
          result << [:derive, self.signed_integer(data)]
        when ABSOLUTE
          result << [:absolute, self.unsigned_integer(data)]
        else
          raise "unkonwn value type: #{type}"
        end

        j += 1
      end

      result
    end

    def self.string frame, i, size
      frame[4 + i, (size - 5)]
    end

    def self.numeric frame, i, size
      unsigned_integer frame[4 + i, 8]
    end

    def self.time_high_res frame, i, size
      Time.at(numeric(frame, i, size).to_f / FACTOR_HR)
    end

    def self.interval_high_res frame, i, size
      numeric(frame, i, size).to_f / FACTOR_HR
    end

    # Maintain a current frame, and yield a copy of it to the subscribing
    # block.
    #
    # Reading a 'values' part is the indicator that a block is 'ready'.
    def self.parse frame
      raise "invalid frame" if frame.size < 4

      current = {}

      i = 0

      loop do
        break if i >= frame.size

        type, size = frame[i,4].unpack("nn")

        case type
        when HOST
          current[:host] = self.string(frame, i, size)
        when TIME
          current[:time] = Time.at(self.numeric(frame, i, size))
        when TIME_HR
          current[:time] = self.time_high_res(frame, i, size)
        when PLUGIN
          current[:plugin] = self.string(frame, i, size)
        when PLUGIN_INSTANCE
          current[:plugin_instance] = self.string(frame, i, size)
        when TYPE
          current[:type] = self.string(frame, i, size)
        when TYPE_INSTANCE
          current[:type_instance] = self.string(frame, i, size)
        when VALUES
          values = self.values(frame, i, size)
          current[:values] = values
          yield current
        when INTERVAL
          current[:interval] = self.numeric(frame, i, size).to_f
        when INTERVAL_HR
          current[:interval] = self.interval_high_res(frame, i, size)
        when MESSAGE
          current[:message] = self.string(frame, i, size)
        when SEVERITY
          current[:severity] = self.numeric(frame, i, size)
        else
          log.warning("cannot understand type: #{type}")
        end

        i += size
      end
    end
  end
end
