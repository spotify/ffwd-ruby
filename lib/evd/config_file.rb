require 'yaml'

module EVD
  class ConfigFile
    def initialize(path)
      @content = YAML.load_file(path)
    end
  end
end
