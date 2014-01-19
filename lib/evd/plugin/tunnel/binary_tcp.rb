require 'eventmachine'
require 'json'

require_relative 'base_tcp'

require_relative '../../connection'

module EVD::Plugin::Tunnel
  class BinaryTCP < EVD::Connection
    include EVD::Logging
    include BaseTCP

    def receive_line line
      if not @metadata
        receive_metadata JSON.load(line)
        return
      end

      set_binary_mode
    end

    def receive_binary_data(data)
    end
  end
end
