require 'logger'

module EVD
  def self.log
    return @log unless @log.nil?
    log = Logger.new(log_config[:stream])
    log.level = log_config[:level]
    @log = log
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

  class ClassLogger
    def initialize(klass)
      @klass_name = klass.name
    end

    def info(message, *args)
      EVD.log.info("#{@klass_name}: #{message}", *args)
    end

    def error(message, *args)
      EVD.log.error("#{@klass_name}: #{message}", *args)
    end

    def warning(message, *args)
      EVD.log.warning("#{@klass_name}: #{message}", *args)
    end

    def debug(message, *args)
      EVD.log.debug("#{@klass_name}: #{message}", *args)
    end
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
      klass.log = ClassLogger.new(klass)
    end
  end
end
