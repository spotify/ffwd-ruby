require_relative 'logging'
require_relative 'lifecycle'

module FFWD::Processor
  include FFWD::Lifecycle
  include FFWD::Logging

  class Setup
    attr_reader :name

    def initialize name, klass, options
      @name = name
      @klass = klass
      @options = options
    end

    def setup emitter
      @klass.new emitter, @options
    end
  end

  # Module to include for processors.
  #
  # Usage:
  #
  # class MyProcessor
  #   include FFWD::Processor
  #
  #   register_processor "my_processor"
  #
  #   def initialize opts
  #     .. read options ..
  #   end
  #
  #   def start emitter
  #     ... setup EventMachine tasks ...
  #   end
  #
  #   def process emitter, m
  #     ... process a single metric ...
  #     emitter.metrics.emit ...
  #   end
  # end
  def process m
    raise Exception.new("process: Not Implemented")
  end

  module ClassMethods
    def register_processor(name)
      unless FFWD::Processor.registry[name].nil?
        raise "Already registered '#{name}'"
      end

      FFWD::Processor.registry[name] = self
    end
  end

  def name
    self.class.name
  end

  def self.registry
    @@registry ||= {}
  end

  def self.category
    'processor'
  end

  def self.included(mod)
    mod.extend ClassMethods
  end

  def self.load_discovered source
  end

  # setup hash of processor setup classes.
  def self.load_processors config
    registry.map{|name, klass| Setup.new name, klass, config[name] || {}}
  end
end
