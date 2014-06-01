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

module FFWD
  module Plugin
    class Loaded
      attr_reader :source, :name, :description, :options

      def initialize source, name, config
        @source = source
        @name = name
        @mod = config[:mod]
        @description = config[:description]
        @options = config[:options]
        @setup_input_method = load_method @mod, config[:setup_input_method_name]
        @setup_output_method = load_method @mod, config[:setup_output_method_name]
      end

      def capabilities
        capabilities = []

        if not @setup_input_method.nil?
          capabilities << "input"
        end

        if not @setup_output_method.nil?
          capabilities << "output"
        end

        return capabilities
      end

      def can?(kind)
        not get(kind).nil?
      end

      def get(kind)
        return @setup_input_method if kind == :input
        return @setup_output_method if kind == :output
        return nil
      end

      private

      def load_method mod, method_name
        return nil unless mod.respond_to? method_name
        return mod.method method_name
      end
    end

    class Setup
      attr_reader :config, :name

      def initialize method, config, name
        @method = method
        @config = config
        @name = name
      end

      def call *args
        @method.call(*args)
      end
    end

    def self.discovered
      @@discovered ||= {}
    end

    def self.loaded
      @@loaded ||= {}
    end

    module ClassMethods
      def register_plugin(name, opts={})
        config = {
          :mod => self,
          :description => opts[:description],
          :options => opts[:options] || []
        }

        config[:setup_input_method_name] = (opts[:setup_input_method] || :setup_input)
        config[:setup_output_method_name] = (opts[:setup_output_method] || :setup_output)

        FFWD::Plugin.discovered[name] = config
      end
    end

    def self.included mod
      mod.extend ClassMethods
    end

    def self.category
      'plugin'
    end

    def self.load_discovered source
      FFWD::Plugin.discovered.each do |name, config|
        FFWD::Plugin.loaded[name] = Loaded.new source, name, config
      end

      FFWD::Plugin.discovered.clear
    end

    def self.load_plugins log, kind_name, config, kind, m
      result = []

      return result if config.nil?

      config.each_with_index do |plugin_config, index|
        d = "#{kind_name} plugin ##{index}"

        unless name = plugin_config[:type]
          log.error "#{d}: Missing :type attribute for '#{kind_name}'"
          next
        end

        unless plugin = FFWD::Plugin.loaded[name]
          log.error "#{d}: Not an available plugin '#{name}'"
          next
        end

        unless setup = plugin.get(kind)
          log.error "#{d}: Not an #{kind_name} plugin '#{name}'"
          next
        end

        factory = setup.call plugin_config

        unless factory.respond_to? m
          log.error "#{d}: Plugin '#{name}' does not support '#{m.to_s}'"
          next
        end

        result << Setup.new(factory.method(m), plugin_config, name)
      end

      return result
    end

    def self.option name, opts={}
      {:name => name, :default => opts[:default], :help => opts[:help],
       :modes => opts[:modes]}
    end
  end
end
