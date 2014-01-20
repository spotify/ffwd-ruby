require 'logger'

module EVD
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
      :progname => 'EVD',
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

    def debug message
      EVD.log.debug(@progname){message}
    end

    def info message
      EVD.log.info(@progname){message}
    end

    def warning message
      EVD.log.warn(@progname){message}
    end

    def error message, e=nil
      EVD.log.error(@progname){message}

      return unless e

      EVD.log.error(@progname){"Caused by: #{e}"}
      e.backtrace.each do |b|
        EVD.log.error(@progname){"  #{b}"}
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

      if EVD.log_disabled?
        klass.log = FakeLogger.new
      else
        klass.log = ClassLogger.new klass
      end
    end
  end
end
