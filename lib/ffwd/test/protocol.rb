require 'ffwd/handler'
require 'ffwd/connection'

module FFWD::Test
  module Protocol
    def valid_output klass, opts={}
      expect(klass < FFWD::Handler).to be true
      sig = double
      connect = double
      config = opts[:config] || double
      expect(klass.respond_to?(:plugin_type)).to be true
      expect(klass.plugin_type.nil?).to be false
      return klass.new sig, connect, config
    end

    def valid_input klass, opts={}
      expect(klass < FFWD::Connection).to be true
      sig = double
      bind = double
      core = double
      config = opts[:config] || double
      expect(klass.respond_to?(:plugin_type)).to be true
      expect(klass.plugin_type.nil?).to be false
      return klass.new sig, bind, core, config
    end
  end
end
