require_relative 'logging'
require_relative 'lifecycle'

module FFWD::Processor
  include FFWD::Lifecycle
  include FFWD::Logging

  # Module to include for processors.
  #
  # Usage:
  #
  # class MyProcessor
  #   include FFWD::Processor
  #
  #   register_type "my_processor"
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
    def register_type(name)
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

  #
  # setup hash of datatype functions.
  #
  def self.load config
    processors = {}

    registry.each do |name, klass|
      opts = config[name] || {}
      processors[name] = lambda{|emitter| klass.new emitter, opts}
    end

    if processors.empty?
      raise "No processors loaded"
    end

    log.info "Loaded processors: #{processors.keys.sort.join(', ')}"
    return processors
  end
end
