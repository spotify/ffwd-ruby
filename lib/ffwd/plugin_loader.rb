require_relative 'logging'
require_relative 'plugin'

# Some crazy code to load modules from a specific directory structure.
module FFWD::PluginLoader
  include FFWD::Logging

  MODULE_NAME = 'ffwd'

  def self.load_paths
    $LOAD_PATH.each do |path|
      yield "from $LOAD_PATH: #{path}", path
    end

    Gem::Specification.latest_specs(true).collect do |spec|
      yield "from gem: #{spec.full_name}", File.join(spec.full_gem_path, 'lib')
    end
  end

  def self.list_modules(module_category, blacklist, &block)
    load_paths do |source, path|
      dir = File.join(path, MODULE_NAME, module_category)

      next unless File.directory? dir

      Dir.foreach(dir) do |entity|
        next if entity.start_with? "."
        next unless entity.end_with? ".rb"
        next unless File.file? File.join(dir, entity)

        base = entity.slice(0, entity.size - 3)

        if blacklist.include? base
          log.warning "Ignoring blacklisted module: #{base}"
          next
        end

        path = [MODULE_NAME, module_category, base].join('/')
        yield source, path
      end
    end
  end

  def self.load module_category, blacklist
    self.list_modules(module_category, blacklist) do |source, m|
      require m
      # Initialize all newly discovered plugins.
      FFWD::Plugin.init_discovered source
    end
  end
end
