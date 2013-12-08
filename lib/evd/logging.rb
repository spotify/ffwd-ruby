require 'logger'

module EVD
  def self.log
    @log ||= Logger.new(log_config[:stream]).tap do |l|
      l.level = log_config[:level]
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

  def self.log_setup(log_opts={})
    @log_opts = log_opts
  end

  def self.log_disable
    @log_disable = true
  end

  def self.log_disabled?
    @log_disable || false
  end

  class ClassLogger
    def initialize(klass)
      @klass_name = klass.name
    end

    def info(message, *args)
      EVD.log.info("#{@klass_name}: #{message}", *args)
    end

    def error(message, e = nil, *args)
      EVD.log.error("#{@klass_name}: #{message}", *args)
      return unless e
      EVD.log.error("#{@klass_name}: Exception: #{e}")
      e.backtrace.each do |bt|
        EVD.log.error("  #{bt}")
      end
    end

    def warning(message, *args)
      EVD.log.warn("#{@klass_name}: #{message}", *args)
    end

    def debug(message, *args)
      EVD.log.debug("#{@klass_name}: #{message}", *args)
    end
  end

  class FakeLogger
    def info(message, *args); end
    def error(message, *args); end
    def warning(message, *args); end
    def debug(message, *args); end
  end

  module Logging
    module ClassMethods
      attr_accessor :log
    end

    def log
      self.class.log
    end

    def self.included(klass)
      klass.extend ClassMethods

      if EVD.log_disabled?
        klass.log = FakeLogger.new
      else
        klass.log = ClassLogger.new(klass)
      end
    end
  end
end
