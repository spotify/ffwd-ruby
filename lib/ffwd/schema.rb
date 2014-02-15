module FFWD
  SCHEMA_DEFAULT_SUPPORT = [
    :dump_metric,
    :dump_event
  ]

  DEFUALT_SCHEMA = 'default'
  DEFAULT_CONTENT_TYPE = 'application/json'

  def self.parse_schema opts, support=SCHEMA_DEFAULT_SUPPORT
    name = opts[:schema] || DEFUALT_SCHEMA
    content_type = opts[:content_type] || DEFAULT_CONTENT_TYPE
    key = [name, content_type]

    schema = FFWD::Schema.loaded[key]

    if schema.nil?
      raise "No schema '#{name}' for content type '#{content_type}'"
    end

    unless schema.support? support
      raise "Schema #{schema} does not support all of: #{support}"
    end

    return schema.mod
  end

  module Schema
    class Loaded
      attr_reader :source, :mod

      def initialize source, mod
        @source = source
        @mod = mod
      end

      def support? support
        support.each do |m|
          return false unless @mod.respond_to? m
        end

        return true
      end
    end

    def self.loaded
      @@loaded ||= {}
    end

    def self.discovered
      @@discovered ||= {}
    end

    module ClassMethods
      def register_schema name, content_type, impl
        key = [name, content_type]
        FFWD::Schema.discovered[key] = impl
      end
    end

    def self.included mod
      mod.extend ClassMethods
    end

    def self.category
      'schema'
    end

    def self.load_discovered source
      FFWD::Schema.discovered.each do |key, mod|
        FFWD::Schema.loaded[key] = Loaded.new source, mod
      end

      FFWD::Schema.discovered.clear
    end
  end
end
