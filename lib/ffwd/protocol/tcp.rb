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

require_relative '../tunnel/tcp'

require_relative 'tcp/bind'
require_relative 'tcp/plain_connect'
require_relative 'tcp/flushing_connect'
require_relative 'tcp/connection'

module FFWD::TCP
  def self.family
    :tcp
  end

  class SetupOutput
    attr_reader :config

    def initialize config, log, handler, args
      @config = Hash[config]
      @log = log
      @handler = handler
      @args = args

      @config = Connection.prepare @config

      if @config[:flush_period] == 0
        @config = PlainConnect.prepare @config
        @type = PlainConnect
      else
        @config = FlushingConnect.prepare @config
        @type = FlushingConnect
      end
    end

    def connect core
      raise "Missing required option :host" if (host = @config[:host]).nil?
      raise "Missing required option :port" if (port = @config[:port]).nil?

      c = Connection.new @log, host, port, @handler, @args, @config
      @type.new core, @log, c, @config
    end
  end

  def self.connect config, log, handler, *args
    SetupOutput.new config, log, handler, args
  end

  class SetupInput
    attr_reader :config

    def initialize config, log, connection, args
      @config = Hash[config]
      @log = log
      @connection = connection
      @args = args
    end

    def bind core
      raise "Missing required option :host" if (host = @config[:host]).nil?
      raise "Missing required option :port" if (port = @config[:port]).nil?
      @config = Bind.prepare Hash[@config]
      Bind.new core, @log, host, port, @connection, @args, @config
    end

    def tunnel core, plugin
      raise "Missing required option :port" if (port = @config[:port]).nil?
      FFWD::Tunnel::TCP.new port, core, plugin, @log, @connection, @args
    end
  end

  def self.bind config, log, connection, *args
    SetupInput.new config, log, connection, args
  end
end
