require_relative 'logging'

module EVD::Processor
  include EVD::Logging

  # Module to include for processors.
  #
  # Usage:
  #
  # class MyProcessor
  #   include EVD::Processor
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
  #     emitter.emit_metric ...
  #   end
  # end
  def process m
    raise Exception.new("process: Not Implemented")
  end

  def stopping_callbacks
    @stopping_callbacks ||= []
  end

  def stopping &block
    stopping_callbacks << block
  end

  def stop
    stopping_callbacks.each do |stop|
      begin
        stop.call
      rescue => e
        log.error "Failed to invoke stop callback", e
      end
    end
  end

  module ClassMethods
    def register_type(name)
      unless EVD::Processor.registry[name].nil?
        raise "Already registered '#{name}'"
      end

      EVD::Processor.registry[name] = self
    end
  end

  def name
    self.class.name
  end

  def self.registry
    @@registry ||= {}
  end

  def self.included(mod)
    mod.extend ClassMethods
  end

  #
  # setup hash of datatype functions.
  #
  def self.load config
    processors = {}

    registry.each do |name, klass|
      opts = config[name] || {}
      processors[name] = lambda{klass.new opts}
    end

    if processors.empty?
      raise "No processors loaded"
    end

    log.info "Loaded processors: #{processors.keys.join(', ')}"
    return processors
  end
end
