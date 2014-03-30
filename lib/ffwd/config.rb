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

module FFWD
  module Config
    module Integer
      def self.parse value
        if value.kind_of? Numeric
          return value.to_int
        end

        raise "Not an integer: #{value.inspect}"
      end
    end

    def self.make_parser opts
      if type = opts[:type]
        if type == :int
          return Integer
        end

        if type.respond_to? :parse
          return type
        end
      end

      raise "Unable to determine parseable type from: #{opts}"
    end

    class Field
      attr_reader :name, :setter

      def initialize name, opts={}
        @name = name.to_sym
        @setter = "#{name}=".to_sym
        @parser = FFWD::Config.make_parser opts
        @default = opts[:default]
      end

      def parse value
        value = @default if value.nil?
        @parser.parse value
      end
    end

    class ArrayField < Field
      attr_reader :name, :setter

      def initialize name, opts={}
        @name = name.to_sym
        @setter = "#{name}=".to_sym
        @parser = FFWD::Config.make_parser opts
        @default = opts[:default]
      end

      def parse value
        value = @default if value.nil?

        unless value.is_a? Array
          raise "Expected Array but got: #{value.inspect}"
        end

        value.map do |v|
          @parser.parse v
        end
      end
    end

    module Section
      module ClassMethods
        def fields
          @fields ||= {}
        end

        def section_field name, opts={}
          name = name.to_s
          fields[name] = Field.new name, opts
          attr_accessor name
        end

        def section_array name, opts={}
          name = name.to_s
          fields[name] = ArrayField.new name, opts
          attr_accessor name
        end

        def parse data={}
          instance = new
          instance.update! data
          return instance
        end
      end

      def update! data
        raise "Expected Hash but got: #{data.inspect}" unless data.is_a? Hash

        self.class.fields.each do |key, option|
          send option.setter, option.parse(data[key])
        end
      end

      def notifiers
        @notifiers ||= []
      end

      def notify &cb
        notifiers << cb
      end

      def notify!
        notifiers.each{|cb| cb.call}
      end

      def self.included m
        m.extend ClassMethods
      end
    end
  end
end
