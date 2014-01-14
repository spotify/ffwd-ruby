module EVD
  # Some crazy code to load modules from a specific directory structure.
  module PluginLoader
    MODULE_NAME = 'evd'

    def self.list_modules(module_category, &block)
      $:.each do |path|
        dir = File.join(path, MODULE_NAME, module_category)

        next unless File.directory? dir

        Dir.foreach(dir) do |entity|
          next if entity.start_with? "."
          next unless entity.end_with? ".rb"
          next unless File.file? File.join(dir, entity)

          base = entity.slice(0, entity.size - 3)
          yield [MODULE_NAME, module_category, base].join('/')
        end
      end
    end

    def self.load(module_category)
      self.list_modules(module_category) do |m|
        require m
      end
    end
  end
end
