require 'logger'

module EVD
  def self.log
    @log ||= ::Logger.new(log_config[:stream]).tap do |l|
      l.level = log_config[:level]
      l.progname = "EVD"
    end
  end

  def self.log_config
    return @log_config unless @log_config.nil?

    log_opts = @log_opts || {}

    @log_config = {
      :level => log_opts[:level] || Logger::INFO,
      :stream => log_opts[:stream] || STDOUT,
    }
  end

  def self.log_setup log_opts={}
    @log_opts = log_opts
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
