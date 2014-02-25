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
