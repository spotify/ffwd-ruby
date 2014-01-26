require_relative 'logging'
require_relative 'plugin'

# Some crazy code to load modules from a specific directory structure.
module FFWD::PluginLoader
  include FFWD::Logging

  MODULE_NAME = 'ffwd'

  def self.plugin_directories= directories
    @plugin_directories = directories
  end

  def self.plugin_directories
    @plugin_directories || []
  end

  # Discover plugins in the specified directory that are prefixed with 'ffwd-'.
  def self.discover_plugins dir
    return [] unless File.directory? dir

    Dir.foreach(dir).map do |entity|
      next if entity.start_with? "."
      next unless entity.start_with? "#{MODULE_NAME}-"
      full_path = File.join dir, entity, 'lib'
      next unless File.directory? full_path
      yield full_path
    end
  end

  def self.plugin_paths
    return @plugin_paths if @plugin_paths

    @plugin_paths = []

    plugin_directories.map do |dir|
      discover_plugins(dir) do |path|
        @plugin_paths << path
      end
    end

    return @plugin_paths
  end

  def self.load_paths
    return @load_paths if @load_paths

    @load_paths = []

    Gem::Specification.latest_specs(true).collect do |spec|
      @load_paths << ["from gem: #{spec.full_name}",
                      File.join(spec.full_gem_path, 'lib')]
    end

    plugin_paths.each do |path|
      @load_paths << ["from plugin directory: #{path}", path]
    end

    $LOAD_PATH.each do |path|
      @load_paths << ["from $LOAD_PATH: #{path}", path]
    end

    unless plugin_paths.empty?
      $LOAD_PATH.concat plugin_paths
    end

    return @load_paths
  end

  def self.list_modules module_category, blacklist, &block
    load_paths.each do |source, path|
      dir = File.join(path, MODULE_NAME, module_category)

      next unless File.directory? dir

      Dir.foreach dir do |entity|
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
