module FFWD::Plugin::Collectd
  # A minimal implementation of a reader for collectd's types.db
  #
  # http://collectd.org/documentation/manpages/types.db.5.shtml
  class TypesDB
    def initialize database
      @database = database
    end

    def get_name key, i
      unless entry = @database[key]
        return nil
      end

      unless type_spec = entry[i]
        return nil
      end

      type_spec[0]
    end

    def self.open path
      return nil unless File.file? path

      database = {}

      File.open(path) do |f|
        f.readlines.each do |line|
          next if line.start_with? "#"
          parts = line.split(/[\t ]+/, 2)
          next unless parts.size == 2
          key, value_specs = parts
          value_specs = value_specs.split(",").map(&:strip)
          value_specs = value_specs.map{|s| s.split(':')}
          database[key] = value_specs
        end
      end

      new database
    end
  end
end
