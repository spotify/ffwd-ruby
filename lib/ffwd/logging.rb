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

# Logging functionality.
#
# Defines FFWD::Logging which when included in either a class or module makes
# the 'log' field available both as a class and instance field.
#
# 'log' in turn is an object with the following fields available.
#
# 'debug' - Log a message of level DEBUG..
# 'info' - Log a message of level INFO.
# 'warning' - Log a message of level WARNING.
# 'error' - Log a message of level ERROR.
#
# Every function takes the message to log as the only parameter except 'error'
# which can take an exception as a secondary argument.
#
# If an exception is provided, a stacktrace will be printed to log.
require 'logger'

module FFWD
  def self.log
    @log ||= setup_log
  end

  def self.log_reload
    @log = setup_log
  end

  def self.setup_log
    if log_config[:file]
      file = log_config[:file]
      shift_age = log_config[:shift_age]

      return ::Logger.new(file, shift_age=shift_age).tap do |l|
        l.level = log_config[:level]
        l.progname = log_config[:progname]
      end
    end

    if log_config[:stream]
      return ::Logger.new(log_config[:stream]).tap do |l|
        l.level = log_config[:level]
        l.progname = log_config[:progname]
      end
    end

    raise "cannot setup loggin with options: #{log_config}"
  end

  def self.log_config
    return @log_config unless @log_config.nil?

    @log_config = {
      :file => nil,
      :shift_age => 1,
      :level => Logger::INFO,
      :stream => STDOUT,
      :progname => 'FFWD',
    }
  end

  def self.log_disable
    @log_disable = true
  end

  def self.log_disabled?
    @log_disable || false
  end

  class ClassLogger
    def initialize klass
      @progname = klass.name
    end

    def debug?
      FFWD.log.debug?
    end

    def debug message
      FFWD.log.debug(@progname){message}
    end

    def info message
      FFWD.log.info(@progname){message}
    end

    def warning message
      FFWD.log.warn(@progname){message}
    end

    def error message, e=nil
      FFWD.log.error(@progname){message}

      return unless e

      FFWD.log.error(@progname){"Caused by #{e.class}: #{e}"}
      e.backtrace.each do |b|
        FFWD.log.error(@progname){"  #{b}"}
      end
    end
  end

  class FakeLogger
    def debug message; end
    def info message; end
    def warning message; end
    def error message, e=nil; end
  end

  module Logging
    module ClassMethods
      attr_accessor :log
    end

    def log
      self.class.log
    end

    def self.included klass
      klass.extend ClassMethods

      if FFWD.log_disabled?
        klass.log = FakeLogger.new
      else
        klass.log = ClassLogger.new klass
      end
    end
  end
end
